'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface HospitalCapacityData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; admissions: number | null; signals: number | null; confirmed: number | null }[];
  categories: { category: string; signals: number | null; confirmed: number | null }[];
  entities: Record<string, string | number | null>[];
  auditRisk: { name: string; compliance: number; confirmed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; alerts: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<HospitalCapacityData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Bed Occupancy', 'Admissions vs Plan', 'Admissions Placed Outside Target', 'Confirmed Capacity Overflows'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Bed occupancy = occupied bed-days (midnight census) / staffed bed-days. Admissions vs plan = admissions / planned admissions for the 90-day window. Placed outside target = admissions that waited longer than the group placement target for a ward bed / admissions. A confirmed capacity overflow is a bed-management escalation confirmed on review. Counts are ward-level aggregates; there are no patient records.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'admissions', name: 'Admissions' }, { key: 'signals', name: 'Bed-management escalations' }]} title="Daily Admissions and Bed-Management Escalations" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'signals', name: 'Escalations' }, { key: 'confirmed', name: 'Confirmed overflows' }]} title="Escalations and Confirmed Capacity Overflows by Pressure Driver" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Ward' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Ward type' },
        { key: 'beds', header: 'Staffed beds' }, { key: 'occupancy', header: 'Occupancy (%)' },
        { key: 'admissions', header: 'Admissions' }, { key: 'target', header: 'Plan' }, { key: 'vsPlan', header: 'Vs plan (%)' },
        { key: 'outsideTarget', header: 'Outside target (%)' }, { key: 'confirmed', header: 'Confirmed overflows' }, { key: 'reviews', header: 'Reviews' },
      ]} data={data?.entities ?? []} title="Ward observations" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day capacity overflow risk and admissions forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a ward has a confirmed capacity overflow in the next 7 days,
        from boarding time (today and 7-day average), admissions awaiting a bed, confirmed overflows in the last 30 days, nurse FTE, service tier and ward type.
        These are operational bed-flow scores, not diagnostic or clinical predictions.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} ward-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Ward' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(overflow in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Capacity overflow risk by ward" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Group forecast, next 14 days (admissions per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Ward' }, { key: 'date', header: 'Date' }, { key: 'boardingHours', header: 'Boarding (hours)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Boarding-time anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live bed census: Amazon Data Firehose to S3 to Snowpipe' : 'Live bed census: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated bed-census events are sent to the Firehose stream th-healthcare-hospital-capacity-census (aws/publish_census.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_CENSUS.'
          : 'CALL APP.SIMULATE_CENSUS(n) inserts simulated bed-census events directly into RAW.LIVE_CENSUS (or resume APP.TASK_SIMULATE_CENSUS for a feed every minute). This simulates a bed-management system feed; it is not Snowpipe Streaming.'}
        {' '}Events carry no patient identifiers. The alert APP.LIVE_CENSUS_ALERT logs ALERT events and emails the bed management team.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Census events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="ALERT events" value={String(data?.liveSummary?.alerts ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Ward' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'waitMin', header: 'Wait for bed (min)' },
        { key: 'boardingHours', header: 'Boarding (h)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 bed-census events" />
      <DataTable columns={[
        { key: 'id', header: 'Ward' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'waitMin', header: 'Wait for bed (min)' },
        { key: 'boardingHours', header: 'Boarding (h)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Bed-Flow Audit Compliance" value={kpiVal('Bed-Flow Audit Compliance')} />
        <KPICard title="Equipment Safety Check Coverage" value={kpiVal('Equipment Safety Check Coverage')} />
        <KPICard title="Average Boarding Time" value={kpiVal('Average Boarding Time')} />
      </div>
      <Chart data={data?.auditRisk ?? []} type="scatter" xKey="compliance" xName="Bed-flow audit compliance"
        yKeys={[{ key: 'confirmed', name: 'Confirmed capacity overflows' }]} yDomain={[0, 'auto']}
        title="Bed-flow audit compliance (%) vs confirmed capacity overflows by ward" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that bed-flow audits prevented overflows.</p>
      <ActionMemo persona={{ name: 'Siriporn Chaiyasit', role: 'Group Director of Bed Management (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft bed capacity actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, ward, pressure-driver and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.HOSPITAL_CAPACITY_AGENT. It uses Cortex Analyst over the semantic view APP.HOSPITAL_CAPACITY_ANALYTICS for metrics, and Cortex Search over synthetic bed-flow SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the bed capacity agent" mode="advisor" sampleQuestions={['Which 3 wards have the most confirmed capacity overflows?', 'Which wards are high risk this week and what SOP applies?', 'What is bed occupancy by city?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic hospital wards, daily ward-level bed capacity and a bedside equipment snapshot. There are no patient records or patient identifiers. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION capacity overflow risk model evaluated on a time-based holdout, plus a 14-day FORECAST of admissions with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags boarding-time outliers per ward over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_CENSUS, with a Snowflake alert and email on ALERT events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily admissions and escalations, confirmed capacity overflows by ward, overflow risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_CENSUS inserts simulated bed-census events into RAW.LIVE_CENSUS, with a Snowflake alert and email on ALERT events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Bed-Flow Risk', icon: '', content: planning },
    { id: 'live', label: 'Live Census', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Thai private hospital group: ward-level counts only, no patient data, diagnoses or clinical findings. On-demand snapshots are not live hospital operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No ward observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Thailand Hospital Bed Capacity" tabs={tabs} />;
}
