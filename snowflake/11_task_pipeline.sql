-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_INGEST_CENSUS
  WAREHOUSE = HOSPITAL_WH
  SCHEDULE = 'USING CRON */15 * * * * UTC'
  COMMENT = 'Ingest real-time bed census updates'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_REFRESH_FORECASTS
  WAREHOUSE = HOSPITAL_WH
  SCHEDULE = 'USING CRON 0 5 * * * UTC'
  COMMENT = 'Refresh 14-day admission forecasts'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_GENERATE_PLANS
  WAREHOUSE = HOSPITAL_WH
  AFTER APP.TASK_REFRESH_FORECASTS
  COMMENT = 'Generate daily capacity planning recommendations'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_GENERATE_PLANS RESUME;
ALTER TASK APP.TASK_REFRESH_FORECASTS RESUME;
ALTER TASK APP.TASK_INGEST_CENSUS RESUME;
