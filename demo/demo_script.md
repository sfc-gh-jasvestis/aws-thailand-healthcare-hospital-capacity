# Thailand Hospital Bed Capacity

**Thailand - Fictional Private Hospital Group**
Use case: Bed occupancy, admission placement and capacity overflow risk

> Bed capacity for 40 wards in a fictional Thai private hospital group across 5 cities: dynamic tables, a holdout-evaluated capacity overflow classifier, an admissions forecast and grounded AI answers. Synthetic, ward-level data only; no patient records or patient identifiers.

## Why Snowflake

- **Dynamic tables** reconcile bed occupancy, admissions against plan, admissions placed outside the target, bed-management escalations, confirmed overflows and bed-flow audit compliance from RAW ward data, with checks in `run_core.py`
- **Overflow classification** gives a holdout-evaluated next-7-day probability per ward
- **Admissions forecast** projects 14 days of admissions with prediction intervals, for bed and nurse capacity planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live bed census**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.WARDS` (40 rows) |
| Fact table | `RAW.WARD_DAILY` (3,600 ward-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `DRIVER_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.OVERFLOW_RISK_SCORES`, `ML.OVERFLOW_RISK_HOLDOUT_METRICS`, `ML.ADMISSIONS_FORECAST`, `ML.BOARDING_ANOMALIES` |

Cities: Bangkok, Chiang Mai, Khon Kaen, Phuket, Hat Yai.
Ward types: Medical, Surgical, ICU, Maternity, Paediatric.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Admissions vs Plan | 99.9% |
| Admissions | 23,391 |
| Bed Occupancy | 82.9% |
| Admissions Placed Outside Target | 26.8% |
| Escalation Confirmation Rate | 37.0% |
| Bed-Management Escalations | 660 |
| Confirmed Capacity Overflows | 244 |
| Overflow Reviews Opened | 106 |
| Bed-Flow Audit Compliance | 77.0% |
| Wards Active | 40 |
| Staffed Beds | 1,182 |
| Equipment Safety Check Coverage | 66.3% |
| Equipment Checks Pending | 15 |
| Average Boarding Time | 4.1 h |
| Awaiting a Bed (ward-day total) | 6,681 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day, so forecast and anomaly figures can shift slightly.

## Demo flow

1. Executive Cockpit: KPIs, daily admissions against bed-management escalations, escalations and confirmed overflows by pressure driver, ward table
2. Predictive: holdout metrics, risk bands, 14-day admissions forecast, boarding-time anomalies
3. Bed-Flow Risk: bed-flow audit compliance, equipment safety-check coverage and average boarding time, audit compliance against confirmed overflows, then generate the action memo
4. Live Census: run `CALL APP.SIMULATE_CENSUS(20)` (Snowflake only) or `python aws/publish_census.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_CENSUS_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- The group runs at 82.9% occupancy of staffed bed-days; Bangkok is highest at 83.6%. Admissions are at 99.9% of the 90-day plan, and 26.8% of admissions wait longer than the placement target for a ward bed.
- About one bed-management escalation in three is confirmed as a capacity overflow (37.0%). Bed turnaround produces the most confirmed overflows. Bed-board system outage escalations hit every ward in a city at once and are never confirmed.
- The risk model is evaluated on a time-based holdout: precision 0.50 and recall 0.39 at 0.5, against a 0.31 base rate. Present it as triage for bed-flow effort, not a verdict on a ward.
- Bed-board system outages are excluded from model training, because they are not ward-driven.
- This is operational data only. It makes no diagnostic, clinical or medical-efficacy claims and contains no patient records.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
