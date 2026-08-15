-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.OPERATIONS_POLICY_SEARCH
  ON CANCELLATION_NOTES
  ATTRIBUTES REASON_CATEGORY, HOSPITAL, DEPARTMENT
  WAREHOUSE = HOSPITAL_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.CANCELLATIONS
);
