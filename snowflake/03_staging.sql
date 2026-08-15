-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Hospital Capacity & Revenue Optimization
-- Country: THAILAND | Currency: THB
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- HOSPITALS: 12 rows — Private hospitals in group (Bangkok, Samut Prakan, Chiang Mai)
-- BED_CENSUS: 500,000 rows — Real-time bed status data (occupied, available, cleaning) streamed via Kinesis
-- ADMISSIONS: 180,000 rows — 12 months of patient admissions with diagnosis, department, LOS
-- SURGERIES: 45,000 rows — Surgical cases with OR time, team, and scheduling data
-- REVENUE_DATA: 180,000 rows — Revenue per admission (room, procedures, pharmacy, supplies)
-- STAFFING: 8,760 rows — Daily staffing levels by department and hospital
-- CANCELLATIONS: 12,000 rows — Elective surgery and admission cancellations with reasons
-- THAI_PRIVATE_HEALTH: 10 rows — Thailand private healthcare market data
