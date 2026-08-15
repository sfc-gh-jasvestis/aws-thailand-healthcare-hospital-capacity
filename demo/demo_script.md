# Demo Script: Hospital Capacity & Revenue Optimization
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake forecasts hospital admissions, optimizes bed allocation, and predicts revenue — replacing reactive capacity management with proactive ML-driven planning across 12 private hospitals"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Dr. Thanaporn Pongcharoen** | Group COO | React App (SPCS) | Bed utilization, revenue per bed-day, elective surgery scheduling, staffing efficiency |
| **Worawit Thammachot** | Hospital Operations Director | Amazon QuickSight | Daily census, discharge predictions, OR utilization, bed turnaround time |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 8 tables | HOSPITALS (12), BED_CENSUS (500000), ADMISSIONS (180000), SURGERIES (45000), REVENUE_DATA (180000), STAFFING (8760), CANCELLATIONS (12000), THAI_PRIVATE_HEALTH (10) |
| **CURATED** | 4 Dynamic Tables | REALTIME_BED_STATUS, ADMISSION_TIMESERIES, REVENUE_PER_BED_DAY, OR_UTILIZATION |
| **ML** | ML.FORECAST + ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY, AI_EXTRACT | Classification + extraction |
| **Search** | Cortex Search | 12000 documents indexed |
| **Agent** | HOSPITAL_CAPACITY_AGENT | Semantic View + Search tools |


---

## The Story

Thailand's private hospital group operates 12 hospitals with 3,200 beds — but reactive capacity management means 3 hospitals hit capacity limits while others have headroom, costing ฿1.4B in annual revenue opportunity. ML-powered admission forecasting and revenue optimization transforms operations from reactive to predictive.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "Group bed utilization at 84% — 3 hospitals above 90% (capacity risk)."

**Action**: Point at utilization gauge by hospital

### [0:45–1:30] ADMISSION FORECASTS

**Show**: Admission Forecasts tab

> "ML.FORECAST predicts admissions 14 days ahead by hospital and department."

**Action**: Show 14-day admission forecast by hospital

### [1:30–2:15] REVENUE OPTIMIZATION

**Show**: Revenue Optimization tab

> "Revenue per bed-day varies 3x between departments: cardiac ฿45K vs general ฿15K."

**Action**: Show revenue-per-bed-day by department

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Dr. Thanaporn asks: 'Which hospital should we expand capacity at?'"

**Action**: Type: 'Which hospital should we expand capacity?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Seven Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST for hospital admission prediction** — Only demo forecasting patient admissions at hospital × department granularity 14 days ahead
2. **Real-time bed census via Kinesis streaming** — 15-minute refresh of bed status across 3,200 beds from hospital ADT systems
3. **Revenue per bed-day optimization** — Case-mix optimization maximizing revenue within capacity constraints
4. **Thai private hospital context** — 12 hospitals (Bangkok Dusit Medical, Bumrungrad-style) with realistic Thai patient demographics
5. **Cancellation pattern analysis** — AI_CLASSIFY identifies cancellation root causes for targeted intervention
6. **Capacity alert automation** — Proactive alerts when predicted utilization exceeds threshold — not after beds are full


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM HOSPITAL_CAPACITY.RAW.BED_CENSUS` → 500000
- [ ] `SELECT COUNT(*) FROM HOSPITAL_CAPACITY.RAW.ADMISSIONS` → 180000
- [ ] `SELECT COUNT(*) FROM HOSPITAL_CAPACITY.CURATED.REALTIME_BED_STATUS WHERE UTILIZATION > 0.90` → 3

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM HOSPITAL_CAPACITY.ML.ADMISSION_FORECAST_RESULTS` → >0
- [ ] `SELECT SUM(CASE WHEN IS_ANOMALY THEN 1 ELSE 0 END) FROM HOSPITAL_CAPACITY.ML.CENSUS_ANOMALY_RESULTS` → >=5

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM HOSPITAL_CAPACITY.AI.CANCELLATION_CLASSIFICATIONS` → 12000

