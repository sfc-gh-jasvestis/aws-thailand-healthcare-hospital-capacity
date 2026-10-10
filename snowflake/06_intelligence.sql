-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live bed-census alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_CENSUS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic bed-flow knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.WARD_SOP_DOCS AS
WITH drivers AS (
  SELECT DISTINCT r.PRESSURE_DRIVER, s.CATEGORY
  FROM RAW.WARD_DAILY r JOIN RAW.WARDS s ON s.ID = r.ENTITY_ID
  WHERE r.OVERFLOW_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, PRESSURE_DRIVER)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  PRESSURE_DRIVER,
  CATEGORY || ' ward - ' || PRESSURE_DRIVER || ' capacity overflow follow-up' AS TITLE,
  'Synthetic demo SOP for hospital bed-flow operations; not clinical, diagnostic or regulatory guidance. Ward type: ' || CATEGORY
  || '. Pressure driver: ' || PRESSURE_DRIVER || '. '
  || 'Step 1: log the escalation in the bed-management tracker and notify the duty bed manager within 1 hour. '
  || 'Step 2: ' || CASE
       WHEN PRESSURE_DRIVER = 'Delayed discharges' THEN 'list beds with a planned discharge today that are still occupied after 11:00 and ask the ward lead to confirm transport and paperwork.'
       WHEN PRESSURE_DRIVER = 'ED boarding' THEN 'compare emergency department admissions waiting for a bed with open beds across the hospital and request a cross-ward placement.'
       WHEN PRESSURE_DRIVER = 'Nurse staffing gap' THEN 'compare the nursing roster with staffed beds for the next two shifts and request cover from the hospital float pool.'
       WHEN PRESSURE_DRIVER = 'Elective surge' THEN 'review the next 48 hours of elective admissions with the theatre scheduler and agree which bookings can move without breaching the booking policy.'
       WHEN PRESSURE_DRIVER = 'Bed turnaround' THEN 'list beds waiting for cleaning for more than 60 minutes and escalate them to the housekeeping supervisor.'
       WHEN PRESSURE_DRIVER = 'Step-down bed shortage' THEN 'list ICU patients ready for step-down and ask the receiving ward to reserve a bed before the next bed meeting.'
       ELSE 'review the flagged records against the ward profile and escalate if unexplained.'
     END
  || ' Step 3: if occupancy stays above 95% of staffed beds or average boarding stays above 6 hours after follow-up, schedule a bed-flow review with the ward manager. '
  || 'Step 4: record the root cause; if the overflow is confirmed, open an overflow review for the hospital operations lead to approve.' AS CONTENT
FROM drivers;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.WARD_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, PRESSURE_DRIVER
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, PRESSURE_DRIVER, CONTENT FROM SEARCH.WARD_SOP_DOCS);

-- ---------- Boarding-time anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.BOARDING_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, BOARDING_HOURS::FLOAT AS BOARDING_HOURS
FROM RAW.WARD_DAILY;
CREATE OR REPLACE VIEW ML.BOARDING_TRAIN AS
SELECT * FROM ML.BOARDING_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.BOARDING_SERIES);
CREATE OR REPLACE VIEW ML.BOARDING_DETECT AS
SELECT * FROM ML.BOARDING_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.BOARDING_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.BOARDING_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.BOARDING_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'BOARDING_HOURS',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.BOARDING_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS BOARDING_HOURS, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.BOARDING_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.BOARDING_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'BOARDING_HOURS'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.HOSPITAL_CAPACITY_ANALYTICS
  TABLES (
    wards AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per hospital ward, 90-day totals',
    risk AS ML.OVERFLOW_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day capacity overflow probability per ward',
    drivers AS CURATED.DRIVER_SUMMARY PRIMARY KEY (PRESSURE_DRIVER)
      COMMENT = 'Bed-management escalations, confirmed capacity overflows and overflow reviews by pressure driver, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Group-wide totals per day'
  )
  RELATIONSHIPS (risk_ward AS risk (ENTITY_ID) REFERENCES wards)
  FACTS (
    wards.admissions_f AS ADMISSION_COUNT,
    wards.intarget_f AS IN_TARGET_COUNT,
    wards.target_f AS PLANNED_ADMISSIONS_90D,
    wards.occupied_f AS OCCUPIED_BED_DAYS,
    wards.staffed_f AS STAFFED_BED_DAYS,
    wards.escalations_f AS ESCALATION_COUNT,
    wards.overflows_f AS OVERFLOW_COUNT,
    wards.reviews_f AS REVIEW_COUNT,
    wards.audit_due_f AS AUDIT_DUE,
    wards.audit_done_f AS AUDIT_COMPLETED,
    risk.overflow_prob_f AS OVERFLOW_PROB_7D,
    drivers.type_signals_f AS ESCALATION_COUNT,
    drivers.type_confirmed_f AS OVERFLOW_COUNT,
    drivers.type_reviews_f AS REVIEW_COUNT,
    daily.day_admissions_f AS ADMISSION_COUNT,
    daily.day_intarget_f AS IN_TARGET_COUNT,
    daily.day_escalations_f AS ESCALATION_COUNT
  )
  DIMENSIONS (
    wards.ward_id AS ENTITY_ID WITH SYNONYMS = ('ward', 'entities', 'hospital ward'),
    wards.ward_name AS ENTITY_NAME,
    wards.city AS REGION WITH SYNONYMS = ('city', 'province', 'region') COMMENT = 'Thai city where the hospital ward is located',
    wards.ward_type AS CATEGORY WITH SYNONYMS = ('ward type', 'specialty'),
    wards.service_tier AS SERVICE_TIER COMMENT = 'Service tier 1 (community) to 3 (tertiary)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    drivers.pressure_driver AS PRESSURE_DRIVER WITH SYNONYMS = ('driver', 'pressure cause', 'bottleneck'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    wards.ward_count AS COUNT(wards.admissions_f) WITH SYNONYMS = ('number of wards', 'entities count'),
    wards.total_in_target AS SUM(wards.intarget_f) WITH SYNONYMS = ('placed in target', 'on-time placements'),
    wards.total_admissions AS SUM(wards.admissions_f) WITH SYNONYMS = ('admissions', 'admission volume'),
    wards.admissions_vs_plan_pct AS 100 * SUM(wards.admissions_f) / NULLIF(SUM(wards.target_f), 0)
      COMMENT = 'Admissions / planned admissions for the 90-day window',
    wards.bed_occupancy_pct AS 100 * SUM(wards.occupied_f) / NULLIF(SUM(wards.staffed_f), 0)
      WITH SYNONYMS = ('occupancy', 'bed utilisation') COMMENT = 'Occupied bed-days / staffed bed-days',
    wards.outside_target_pct AS 100 * (SUM(wards.admissions_f) - SUM(wards.intarget_f)) / NULLIF(SUM(wards.admissions_f), 0)
      COMMENT = 'Admissions placed in a bed after the placement target / admissions',
    wards.escalation_confirm_pct AS 100 * SUM(wards.overflows_f) / NULLIF(SUM(wards.escalations_f), 0)
      COMMENT = 'Confirmed capacity overflows / bed-management escalations raised',
    wards.bed_escalations AS SUM(wards.escalations_f) WITH SYNONYMS = ('escalations', 'flags'),
    wards.confirmed_overflows AS SUM(wards.overflows_f) WITH SYNONYMS = ('capacity overflows', 'overflows'),
    wards.reviews_opened AS SUM(wards.reviews_f) WITH SYNONYMS = ('overflow reviews', 'reviews'),
    wards.audit_compliance_pct AS 100 * SUM(wards.audit_done_f) / NULLIF(SUM(wards.audit_due_f), 0)
      COMMENT = 'Bed-flow audits completed / audits due',
    risk.avg_overflow_prob AS AVG(risk.overflow_prob_f),
    drivers.type_escalations AS SUM(drivers.type_signals_f),
    drivers.type_overflows AS SUM(drivers.type_confirmed_f),
    drivers.type_reviews AS SUM(drivers.type_reviews_f),
    drivers.type_confirmation_pct AS 100 * SUM(drivers.type_confirmed_f) / NULLIF(SUM(drivers.type_signals_f), 0),
    daily.daily_admissions AS SUM(daily.day_admissions_f),
    daily.daily_in_target AS SUM(daily.day_intarget_f),
    daily.daily_escalations AS SUM(daily.day_escalations_f)
  )
  COMMENT = 'Synthetic hospital bed capacity analytics (demo; ward-level aggregates, no patient data)';
-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.HOSPITAL_CAPACITY_AGENT
  COMMENT = 'Hospital bed capacity assistant over a synthetic Thai private hospital group'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give ward IDs and numbers with units. Do not give medical, diagnostic or clinical advice; this is ward-level operational data only."
  orchestration: "Use capacity_analyst for admissions, bed occupancy, placement within target, bed-management escalations, confirmed capacity overflows, overflow reviews, bed-flow audit compliance, wards, cities, ward types and overflow risk. Use sop_search for follow-up procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: capacity_analyst
      description: "Admissions vs plan, bed occupancy, admissions placed outside target, bed-management escalations, confirmed capacity overflows, overflow reviews, bed-flow audit compliance, pressure drivers and overflow risk scores per ward"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic bed-flow SOPs by ward type and pressure driver"
tool_resources:
  capacity_analyst:
    semantic_view: __DEMO_DB__.APP.HOSPITAL_CAPACITY_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.WARD_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live bed-census alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), WARD_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, WAIT_MINUTES FLOAT, BOARDING_HOURS FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION TH_HEALTHCARE_HOSPITAL_CAPACITY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (WARD_ID, EVENT_TS, WAIT_MINUTES, BOARDING_HOURS, SOP_HINT)
    SELECT v.WARD_ID, v.EVENT_TS, v.WAIT_MINUTES, v.BOARDING_HOURS,
           'Check ' || s.CATEGORY || ' ward bed-flow SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_CENSUS v
    JOIN RAW.WARDS s ON s.ID = v.WARD_ID
    LEFT JOIN ML.OVERFLOW_RISK_SCORES r ON r.ENTITY_ID = v.WARD_ID
    WHERE v.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.WARD_ID = v.WARD_ID AND l.EVENT_TS = v.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('TH_HEALTHCARE_HOSPITAL_CAPACITY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Hospital bed capacity alert',
      'New bed-census alerts logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_CENSUS_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_CENSUS v
    WHERE v.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.WARD_ID = v.WARD_ID AND l.EVENT_TS = v.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.DRIVER_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.OVERFLOW_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.OVERFLOW_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.OVERFLOW_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'SERVICE_TIER', SERVICE_TIER, 'NURSE_FTE', NURSE_FTE,
             'BOARDING_HOURS', BOARDING_HOURS, 'AWAITING_BED', AWAITING_BED,
             'BOARDING_7D', BOARDING_7D, 'OVERFLOW_30D', OVERFLOW_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:OVERFLOW::FLOAT, 4) AS OVERFLOW_PROB_7D,
         CASE WHEN PRED:probability:OVERFLOW::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:OVERFLOW::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
