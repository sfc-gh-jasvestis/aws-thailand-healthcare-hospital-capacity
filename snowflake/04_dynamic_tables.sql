-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA CURATED;

-- REALTIME_BED_STATUS: Current bed availability by hospital, department, and type
-- Source: HOSPITALS, BED_CENSUS
CREATE OR REPLACE DYNAMIC TABLE CURATED.REALTIME_BED_STATUS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = HOSPITAL_WH
AS
SELECT * FROM RAW.HOSPITALS;
-- TODO: Replace with actual join/aggregation logic per demo

-- ADMISSION_TIMESERIES: Daily admissions by hospital and department for ML.FORECAST
-- Source: ADMISSIONS
CREATE OR REPLACE DYNAMIC TABLE CURATED.ADMISSION_TIMESERIES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = HOSPITAL_WH
AS
SELECT * FROM RAW.ADMISSIONS;
-- TODO: Replace with actual join/aggregation logic per demo

-- REVENUE_PER_BED_DAY: Revenue optimization metrics by bed type and department
-- Source: REVENUE_DATA, BED_CENSUS
CREATE OR REPLACE DYNAMIC TABLE CURATED.REVENUE_PER_BED_DAY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = HOSPITAL_WH
AS
SELECT * FROM RAW.REVENUE_DATA;
-- TODO: Replace with actual join/aggregation logic per demo

-- OR_UTILIZATION: Operating room utilization and scheduling efficiency
-- Source: SURGERIES
CREATE OR REPLACE DYNAMIC TABLE CURATED.OR_UTILIZATION
  TARGET_LAG = '5 minutes'
  WAREHOUSE = HOSPITAL_WH
AS
SELECT * FROM RAW.SURGERIES;
-- TODO: Replace with actual join/aggregation logic per demo

