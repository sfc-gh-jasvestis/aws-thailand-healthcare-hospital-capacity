-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Hospital Capacity & Revenue Optimization
-- ============================================================================
USE DATABASE HOSPITAL_CAPACITY;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.HOSPITAL_CAPACITY_AGENT
  COMMENT = 'Hospital Capacity & Revenue Optimization AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'HOSPITAL_CAPACITY.APP.HOSPITAL_CAPACITY_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'HOSPITAL_CAPACITY.SEARCH.OPERATIONS_POLICY_SEARCH', TOOL_DESCRIPTION => 'Search documents for Healthcare & Medical Tourism information')
  )
  SYSTEM_PROMPT = 'You are the Hospital Capacity Intelligence Agent for 12 private hospitals in Thailand, optimizing bed utilization, surgical scheduling, and revenue per bed-day.';
