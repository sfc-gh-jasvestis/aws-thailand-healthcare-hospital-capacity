# Hospital Capacity & Revenue Optimization

**Thailand - Healthcare & Medical Tourism**
Use case: Capacity Planning & Revenue Optimization

> Hospital capacity intelligence for 12 Thai private hospitals — Kinesis streams bed census data, ML.FORECAST predicts admissions 14 days ahead, and Alerts notify operations when capacity thresholds are breached.

## Why Snowflake

Snowflake forecasts hospital admissions, optimizes bed allocation, and predicts revenue — replacing reactive capacity management with proactive ML-driven planning across 12 private hospitals

- **ML.FORECAST for hospital admission prediction** - Only demo forecasting patient admissions at hospital × department granularity 14 days ahead
- **Real-time bed census via Kinesis streaming** - 15-minute refresh of bed status across 3,200 beds from hospital ADT systems
- **Revenue per bed-day optimization** - Case-mix optimization maximizing revenue within capacity constraints
- **Thai private hospital context** - 12 hospitals (Bangkok Dusit Medical, Bumrungrad-style) with realistic Thai patient demographics
- **Cancellation pattern analysis** - AI_CLASSIFY identifies cancellation root causes for targeted intervention
- **Capacity alert automation** - Proactive alerts when predicted utilization exceeds threshold — not after beds are full

## What is deployed

| | |
|---|---|
| Database | `THAILAND_HEALTHCARE_HOSPITAL_CAPACITY` |
| Service | `THAILAND_HEALTHCARE_HOSPITAL_CAPACITY_APP` |
| Compute pool | `SEA_DEMOS_THAILAND_POOL` |
| Dimension table | `RAW.THAI_PRIVATE_HEALTH` (20 rows) |
| Fact table | `RAW.BED_CENSUS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | THB (฿) |

Regions in play: Bangkok, Chonburi, Rayong, Chiang Mai, Songkhla
Segments: Intensive Care, General Ward, Operating Theatre, Emergency

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh THAILAND_HEALTHCARE_HOSPITAL_CAPACITY
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Bed Occupancy | `84.2%` | average per event |
| ICU Availability | `12 beds` | average per event |
| Avg Length of Stay | `4.2 days` | average per event |
| Facilities Monitored | `124` | total across Thai Private Health |
| Predicted Surge (7d) | `+8%` | average per event |
| Surgery Queue | `342` | total across Thai Private Health |
| ER Wait (Avg) | `47 min` | average per event |


## Demo flow

1. Executive Cockpit
2. Admission Forecasts
3. Revenue Optimization
4. Ask AI
5. Architecture & Data

## Talking points

- **84% utilization** - group average (3 hospitals above 90% — capacity risk)
- **฿1.4B gap** - annual revenue opportunity from sub-optimal case mix (US$40M)
- **8.2% cancellation** - rate costing ฿340M in lost revenue
- **14-day forecast** - admission predictions by hospital and department
- **500K events** - bed census updates streamed via Kinesis
- **3,200 beds** - monitored across 12 private hospitals

## Business impact

- Thailand's private hospital market valued at ฿280B (US$8B) with 340+ facilities (Krungsri Research)
- ML-powered capacity planning improves bed utilization by 8-15% and reduces cancellations by 25% (McKinsey Healthcare Operations)
- Bangkok Dusit Medical Services (BDMS) operates 50 hospitals with 8,400 beds across Thailand (BDMS)
- Optimized surgical scheduling increases OR revenue by 15-20% without additional capacity (Harvard Business Review Health)

---
Generated from `generator/demo_specs/aws-thailand-healthcare-hospital-capacity.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-thailand-healthcare-hospital-capacity` instead.
