-- ============================================================================
-- 01_MARKETPLACE_INSTALL.SQL — Install marketplace data for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA RAW;

-- Free listings to install from Snowflake Marketplace:
-- Install: Snowflake Public Data (Free)
--   https://app.snowflake.com/marketplace/listing/GZTSZ290BV255

-- Paid listing (mock): CEIC ASEAN Macro
--   Real data: https://app.snowflake.com/marketplace/listing/GZTSZRC7HPI
--   Using mock table: THAI_PRIVATE_HEALTH
CREATE TABLE IF NOT EXISTS RAW.THAI_PRIVATE_HEALTH (
  ID INT AUTOINCREMENT, DATA VARIANT, LOADED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

