-- ============================================================================
-- Hospital Capacity & Revenue Optimization
-- Hospital capacity intelligence for 12 Thai private hospitals — Kinesis streams bed census data, ML.FORECAST predicts admissions 14 days ahead, and Alerts notify operations when capacity thresholds are breached.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS HOSPITAL_CAPACITY;
CREATE WAREHOUSE IF NOT EXISTS HOSPITAL_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE HOSPITAL_CAPACITY;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE HOSPITAL_WH;
