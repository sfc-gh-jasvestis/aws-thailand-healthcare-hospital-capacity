-- Generated from generator/demo_specs/aws-thailand-healthcare-hospital-capacity.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-thailand-healthcare-hospital-capacity
-- This is the schema that is actually deployed for THAILAND_HEALTHCARE_HOSPITAL_CAPACITY.

-- THAILAND_HEALTHCARE_HOSPITAL_CAPACITY  (Hospital Capacity & Revenue Optimization)
-- generated from generator/demo_specs/aws-thailand-healthcare-hospital-capacity.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS THAILAND_HEALTHCARE_HOSPITAL_CAPACITY;
CREATE SCHEMA IF NOT EXISTS THAILAND_HEALTHCARE_HOSPITAL_CAPACITY.RAW;
CREATE SCHEMA IF NOT EXISTS THAILAND_HEALTHCARE_HOSPITAL_CAPACITY.CURATED;
CREATE SCHEMA IF NOT EXISTS THAILAND_HEALTHCARE_HOSPITAL_CAPACITY.APP;
USE DATABASE THAILAND_HEALTHCARE_HOSPITAL_CAPACITY;

-- 5 real regions; entity names carry their region so the two always agree
