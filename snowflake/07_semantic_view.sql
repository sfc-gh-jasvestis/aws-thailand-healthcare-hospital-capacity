-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.HOSPITAL_CAPACITY_ANALYTICS
  COMMENT = 'Hospital capacity, revenue optimization, and admission forecasting'
AS
  TABLES (
    CURATED.REALTIME_BED_STATUS AS realtime_bed_status,CURATED.ADMISSION_TIMESERIES AS admission_timeseries,CURATED.REVENUE_PER_BED_DAY AS revenue_per_bed_day,CURATED.OR_UTILIZATION AS or_utilization
  );
