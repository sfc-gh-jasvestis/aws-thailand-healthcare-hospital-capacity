-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_thailand_healthcare_hospital_capacity_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: CAPACITY_CRITICAL_ALERT
CREATE OR REPLACE ALERT APP.CAPACITY_CRITICAL_ALERT
  WAREHOUSE = HOSPITAL_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Hospital approaching capacity — elective admissions at risk'
IF (EXISTS (
  SELECT 1 FROM CURATED.REALTIME_BED_STATUS
  WHERE 1=1 -- Condition: BED_UTILIZATION > 92% for any hospital
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_healthcare_hospital_capacity_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Hospital Capacity & Revenue Optimization: Hospital approaching capacity — elective admissions at risk',
    'Hospital approaching capacity — elective admissions at risk'
  );

ALTER ALERT APP.CAPACITY_CRITICAL_ALERT RESUME;

-- Alert: REVENUE_DECLINE_ALERT
CREATE OR REPLACE ALERT APP.REVENUE_DECLINE_ALERT
  WAREHOUSE = HOSPITAL_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Revenue per bed-day declining — case mix review needed'
IF (EXISTS (
  SELECT 1 FROM CURATED.REALTIME_BED_STATUS
  WHERE 1=1 -- Condition: REVENUE_PER_BED_DAY < 80% of target for 7 consecutive days
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_healthcare_hospital_capacity_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Hospital Capacity & Revenue Optimization: Revenue per bed-day declining — case mix review needed',
    'Revenue per bed-day declining — case mix review needed'
  );

ALTER ALERT APP.REVENUE_DECLINE_ALERT RESUME;

