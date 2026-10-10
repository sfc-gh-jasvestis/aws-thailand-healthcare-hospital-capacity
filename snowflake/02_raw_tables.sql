-- Synthetic ward-day bed capacity data for a fictional Thai private hospital group.
-- Ward-level aggregate counts only: there are no patient records, no patient
-- identifiers, no diagnoses and no clinical notes. Nothing is seeded as a
-- prediction. Randomness is HASH-seeded, so every rebuild is reproducible:
-- per-ward overflow propensity, drift between bed-flow audits, missed audits,
-- ward-type-weighted pressure drivers, bed-management escalations that are
-- cleared on review, and two regional bed-board system outages.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.WARDS AS
WITH wards AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS WARD_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT WARD_INDEX,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-nurse-roster')), 1000000) / 1e6 AS U_STAFF,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-overflow-base')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-audit-cycle')), 1000000) / 1e6 AS U_AUDIT,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-audit-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-service-tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-admit-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-bed-count')), 1000000) / 1e6 AS U_BEDS,
         MOD(ABS(HASH(WARD_INDEX, 'thhc-admit-plan')), 1000000) / 1e6 AS U_PLAN
  FROM wards
), sized AS (
  SELECT *,
         -- Deterministic spread (5 and 8 are coprime): every city and
         -- ward type is present.
         CASE MOD(WARD_INDEX, 5) WHEN 0 THEN 'Bangkok' WHEN 1 THEN 'Chiang Mai'
              WHEN 2 THEN 'Khon Kaen' WHEN 3 THEN 'Phuket' ELSE 'Hat Yai' END AS REGION,
         CASE MOD(WARD_INDEX, 8) WHEN 0 THEN 'Medical' WHEN 1 THEN 'Medical' WHEN 2 THEN 'Medical'
              WHEN 3 THEN 'Surgical' WHEN 4 THEN 'Surgical' WHEN 5 THEN 'ICU'
              WHEN 6 THEN 'Maternity' ELSE 'Paediatric' END AS CATEGORY
  FROM draws
), beds AS (
  SELECT *,
         IFF(CATEGORY = 'ICU', 8 + FLOOR(U_BEDS * 9), 24 + FLOOR(U_BEDS * 17)) AS STAFFED_BEDS
  FROM sized
)
SELECT 'WARD-' || LPAD(WARD_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic ' || LOWER(CATEGORY) || ' ward ' || LPAD(WARD_INDEX::VARCHAR, 4, '0') AS NAME,
       REGION, CATEGORY, WARD_INDEX,
       1 + FLOOR(U_TIER * 3) AS SERVICE_TIER,
       STAFFED_BEDS,
       ROUND(3 + U_STAFF * 9, 1) AS NURSE_FTE,
       -- Mean admissions into the ward per day.
       STAFFED_BEDS * (0.17 + 0.11 * U_VOLUME) * IFF(CATEGORY = 'ICU', 0.5, 1) AS ADMIT_RATE,
       -- Planned admissions for the 90-day window (synthetic capacity plan).
       ROUND(STAFFED_BEDS * (0.17 + 0.11 * U_VOLUME) * IFF(CATEGORY = 'ICU', 0.5, 1)
             * 90 * (0.93 + 0.15 * U_PLAN)) AS PLANNED_ADMISSIONS_90D,
       -- Base daily probability of a confirmed capacity overflow 0.5%-3%;
       -- ~14% of wards are persistent outliers (x3).
       (0.005 + U_RATE * 0.025) * IFF(U_RATE > 0.86, 3, 1) AS BASE_OVERFLOW_RATE,
       7 * (1 + FLOOR(U_AUDIT * 3)) AS AUDIT_INTERVAL_DAYS,
       0.52 + U_DISCIPLINE * 0.46 AS AUDIT_COMPLETION_PROB,
       'Active' AS STATUS
FROM beds;

CREATE TABLE RAW.WARD_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two regional bed-board system outages; every ward in the city raises an escalation.
  SELECT * FROM VALUES (31, 'Chiang Mai'), (58, 'Hat Yai') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT w.ID AS ENTITY_ID, w.WARD_INDEX, w.CATEGORY, w.REGION, w.NURSE_FTE, w.ADMIT_RATE,
         w.STAFFED_BEDS, w.BASE_OVERFLOW_RATE, w.AUDIT_INTERVAL_DAYS, w.AUDIT_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + w.WARD_INDEX * 3, w.AUDIT_INTERVAL_DAYS) AS DAYS_SINCE_AUDIT,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-overflow-day')), 1000000) / 1e6 AS U_OVERFLOW,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-escalated')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-cleared')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-pressure')), 1000000) / 1e6 AS U_DRIVER,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-audit-held')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-admits')), 1000000) / 1e6 AS U_ADMIT,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-placed')), 1000000) / 1e6 AS U_IN_TARGET,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-census')), 1000000) / 1e6 AS U_OCC,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-jitter')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(w.ID, d.DAY_INDEX, 'thhc-review')), 1000000) / 1e6 AS U_REVIEW,
         e.REGION IS NOT NULL AS REGIONAL_EVENT
  FROM RAW.WARDS w CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = w.REGION
), audits AS (
  SELECT *,
         IFF(DAYS_SINCE_AUDIT = 0, 1, 0) AS AUDIT_DUE,
         IFF(DAYS_SINCE_AUDIT = 0 AND U_DONE < AUDIT_COMPLETION_PROB, 1, 0) AS AUDIT_COMPLETED,
         -- Bed-flow drift rises between audits; weak follow-through carries it over.
         DAYS_SINCE_AUDIT / AUDIT_INTERVAL_DAYS + (1 - AUDIT_COMPLETION_PROB) AS DRIFT
  FROM base
), overflows AS (
  SELECT *,
         CASE WHEN U_OVERFLOW < LEAST(0.5, BASE_OVERFLOW_RATE * (0.35 + 1.7 * DRIFT) * (1 + 4 / (1 + NURSE_FTE))) / 4 THEN 2
              WHEN U_OVERFLOW < LEAST(0.5, BASE_OVERFLOW_RATE * (0.35 + 1.7 * DRIFT) * (1 + 4 / (1 + NURSE_FTE))) THEN 1
              ELSE 0 END AS OVERFLOW_EVENTS
  FROM audits
), escalations AS (
  SELECT *,
         -- Bed management escalates about 82% of capacity overflows.
         IFF(REGIONAL_EVENT, 0, IFF(U_DETECT < 0.82, OVERFLOW_EVENTS, 0)) AS OVERFLOW_COUNT,
         -- Escalations cleared on review: higher where bed turnover is fastest.
         IFF(REGIONAL_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Medical' THEN 0.13
                                                         WHEN 'Surgical' THEN 0.11
                                                         WHEN 'ICU' THEN 0.09 ELSE 0.07 END, 1, 0)) AS CLEARED_COUNT,
         FLOOR(ADMIT_RATE * (0.6 + 0.8 * U_ADMIT) + U_NOISE) AS ADMISSION_COUNT
  FROM overflows
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       ADMISSION_COUNT,
       -- Admissions placed in a ward bed within the group placement target.
       FLOOR(ADMISSION_COUNT * LEAST(0.98, 0.78 + 0.17 * U_IN_TARGET - 0.07 * DRIFT - 0.09 * OVERFLOW_EVENTS)) AS IN_TARGET_COUNT,
       OVERFLOW_COUNT + CLEARED_COUNT AS ESCALATION_COUNT,
       OVERFLOW_COUNT,
       IFF(OVERFLOW_COUNT > 0 AND U_REVIEW < 0.55, 1, 0) AS REVIEW_OPENED,
       CASE WHEN OVERFLOW_COUNT + CLEARED_COUNT = 0 THEN 'None'
            WHEN REGIONAL_EVENT THEN 'Bed-board system outage'
            WHEN CATEGORY = 'Medical' THEN IFF(U_DRIVER < 0.4, 'Delayed discharges', IFF(U_DRIVER < 0.75, 'ED boarding', 'Nurse staffing gap'))
            WHEN CATEGORY = 'Surgical' THEN IFF(U_DRIVER < 0.45, 'Elective surge', IFF(U_DRIVER < 0.8, 'Delayed discharges', 'Bed turnaround'))
            WHEN CATEGORY = 'ICU' THEN IFF(U_DRIVER < 0.55, 'Step-down bed shortage', 'Nurse staffing gap')
            WHEN CATEGORY = 'Maternity' THEN IFF(U_DRIVER < 0.45, 'Bed turnaround', IFF(U_DRIVER < 0.8, 'Nurse staffing gap', 'Delayed discharges'))
            ELSE IFF(U_DRIVER < 0.5, 'ED boarding', IFF(U_DRIVER < 0.75, 'Bed turnaround', 'Nurse staffing gap')) END AS PRESSURE_DRIVER,
       AUDIT_DUE, AUDIT_COMPLETED,
       STAFFED_BEDS,
       -- Midnight census; capacity overflows push it past staffed beds.
       LEAST(STAFFED_BEDS + 4, ROUND(STAFFED_BEDS * (0.72 + 0.12 * U_OCC + 0.06 * DRIFT + 0.09 * OVERFLOW_EVENTS))) AS OCCUPIED_BEDS,
       -- Median hours from admission decision to ward bed, and admissions awaiting a bed at day end.
       ROUND(1.6 + 2.2 * DRIFT + 3.4 * OVERFLOW_EVENTS + U_NOISE * 1.3, 2) AS BOARDING_HOURS,
       ROUND(ADMIT_RATE * (0.05 + 0.10 * DRIFT + 0.16 * OVERFLOW_EVENTS) + U_NOISE * 2) AS AWAITING_BED,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM escalations;

-- Bedside equipment and safety-check status per ward (snapshot, synthetic).
CREATE TABLE RAW.EQUIPMENT_FLEET AS
WITH units AS (
  SELECT ID, CATEGORY,
         2 + MOD(ABS(HASH(ID, 'thhc-units')), 6) AS INSTALLED,
         MOD(ABS(HASH(ID, 'thhc-checked')), 8) AS CHECKED_DRAW,
         MOD(ABS(HASH(ID, 'thhc-pending')), 3) AS PENDING_DRAW
  FROM RAW.WARDS
)
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Medical' THEN 'Patient monitor' WHEN 'Surgical' THEN 'Infusion pump'
                     WHEN 'ICU' THEN 'Ventilator' WHEN 'Maternity' THEN 'Fetal monitor'
                     ELSE 'Paediatric monitor' END AS EQUIPMENT_TYPE,
       INSTALLED AS UNITS_INSTALLED,
       LEAST(CHECKED_DRAW, INSTALLED) AS UNITS_CHECKED,
       LEAST(PENDING_DRAW, INSTALLED - LEAST(CHECKED_DRAW, INSTALLED)) AS CHECKS_PENDING,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM units;
