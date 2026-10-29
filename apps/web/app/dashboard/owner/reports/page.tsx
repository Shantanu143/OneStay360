"use client";
import { useState } from "react";
import { BarChart3, BedDouble, Download, IndianRupee, TrendingUp } from "lucide-react";
import { Page } from "@/components/dash/shell";
import { Bars, bedStats, Donut, Progress } from "@/components/dash/widgets";
import { Field, Kpi, Loading, Segmented } from "@/components/ui";
import { useQuery } from "@/lib/hooks";
import { money, monthShort, periodOf } from "@/lib/format";
import { downloadCsv } from "@/lib/csv";

const methodColors: Record<string, string> = { Online: "#0e7c66", UPI: "#5dd6b3", Cash: "#f28c28", "Bank Transfer": "#2f6fe4", Cheque: "#8b5cf6" };

export default function ReportsPage() {
  const [range, setRange] = useState<"6" | "12">("6");
  const [property, setProperty] = useState("all");
  const { data, loading, error, reload } = useQuery(async (b) => {
    const [properties, invoices, payments, tenants] = await Promise.all([b.listProperties(), b.listInvoices(), b.listPayments({ status: "paid" }), b.listTenants()]);
    return { properties, invoices, payments, tenants };
  });
  if (loading || !data) {
    return (
      <Page error={error} onRetry={reload} title="Reports">
        <Loading rows={4} />
      </Page>
    );
  }
  const n = +range;
  const inProp = <T extends { propertyId: string }>(x: T) => property === "all" || x.propertyId === property;
  const invoices = data.invoices.filter(inProp);
  const payments = data.payments.filter(inProp);
  const properties = data.properties.filter((p) => property === "all" || p.id === property);
  const months = Array.from({ length: n }, (_, i) => {
    const d = new Date();
    d.setDate(1);
    d.setMonth(d.getMonth() - (n - 1 - i));
    return periodOf(d);
  });
  const chart = months.map((m) => {
    const inv = invoices.filter((i) => i.periodMonth === m);
    return { label: monthShort(m), period: m, total: inv.reduce((s, i) => s + i.amount, 0), value: inv.filter((i) => i.status === "paid").reduce((s, i) => s + i.amount, 0) };
  });
  const totalExpected = chart.reduce((s, c) => s + c.total, 0);
  const totalCollected = chart.reduce((s, c) => s + c.value, 0);
  const since = new Date(months[0] + "-01").getTime();
  const methodTotals = new Map<string, number>();
  for (const p of payments.filter((p) => p.createdAt >= since)) methodTotals.set(p.method, (methodTotals.get(p.method) ?? 0) + p.amount);
  const beds = properties.reduce((a, p) => ({ t: a.t + bedStats(p).total, o: a.o + bedStats(p).occupied }), { t: 0, o: 0 });
  const outstanding = invoices.filter((i) => i.status !== "paid").reduce((s, i) => s + i.amount, 0);

  const exportDues = () => {
    downloadCsv("collections-by-month.csv", [["Month", "Expected", "Collected", "Collection rate"], ...chart.map((c) => [c.period, c.total, c.value, c.total ? `${Math.round((c.value / c.total) * 100)}%` : "—"])]);
  };

  return (
    <Page error={error} onRetry={reload}
      title="Reports"
      sub="Collections, occupancy and payment mix"
      actions={
        <button className="btn btn-ghost btn-sm" onClick={exportDues}>
          <Download size={15} aria-hidden /> Export CSV
        </button>
      }
    >
      <div className="filters" style={{ justifyContent: "space-between" }}>
        <Segmented<"6" | "12">
          label="Time range"
          value={range}
          onChange={setRange}
          options={[
            { value: "6", label: "6 months" },
            { value: "12", label: "12 months" },
          ]}
        />
        <Field label="Property">
        <select className="select" value={property} onChange={(e) => setProperty(e.target.value)} style={{ minWidth: 220 }}>
          <option value="all">All properties</option>
          {data.properties.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        </Field>
      </div>
      <div className="grid-4">
        <Kpi icon={IndianRupee} label="Collected" value={money(totalCollected)} hint={`last ${n} months`} />
        <Kpi icon={TrendingUp} label="Collection rate" value={`${totalExpected ? Math.round((totalCollected / totalExpected) * 100) : 0}%`} hint={`of ${money(totalExpected)} invoiced`} />
        <Kpi icon={BedDouble} label="Occupancy" value={`${beds.t ? Math.round((beds.o / beds.t) * 100) : 0}%`} hint={`${beds.o}/${beds.t} beds`} />
        <Kpi icon={BarChart3} label="Outstanding" value={money(outstanding)} tone={outstanding ? "red" : undefined} />
      </div>
      <div className="glass card">
        <div className="section-title">
          <h2>Monthly collections</h2>
        </div>
        <Bars data={chart} />
      </div>
      <div className="grid-2">
        <div className="glass card">
          <div className="section-title">
            <h2>Payment methods</h2>
          </div>
          {methodTotals.size ? (
            <Donut parts={[...methodTotals.entries()].map(([label, value]) => ({ label, value, color: methodColors[label] ?? "#999" }))} center={<span style={{ fontSize: 14 }}>{money(totalCollected)}</span>} />
          ) : (
            <p className="muted">No payments in this period.</p>
          )}
        </div>
        <div className="glass card">
          <div className="section-title">
            <h2>Occupancy by property</h2>
          </div>
          <div className="stack">
            {properties.map((p) => {
              const s = bedStats(p);
              return (
                <div key={p.id}>
                  <div className="row-between" style={{ fontSize: 14, marginBottom: 6 }}>
                    <b>{p.name}</b>
                    <span className="muted num">
                      {s.occupied}/{s.total} · {s.pct}%
                    </span>
                  </div>
                  <Progress value={s.pct} label={`${p.name} occupancy`} />
                </div>
              );
            })}
          </div>
        </div>
      </div>
      <div className="glass card">
        <div className="section-title">
          <h2>Month by month</h2>
        </div>
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Month</th>
                <th style={{ textAlign: "right" }}>Expected</th>
                <th style={{ textAlign: "right" }}>Collected</th>
                <th style={{ textAlign: "right" }}>Pending</th>
                <th>Rate</th>
              </tr>
            </thead>
            <tbody>
              {[...chart].reverse().map((c) => (
                <tr key={c.period}>
                  <td>{new Date(c.period + "-01").toLocaleDateString("en-US", { month: "long", year: "numeric" })}</td>
                  <td className="num" style={{ textAlign: "right" }}>
                    {money(c.total)}
                  </td>
                  <td className="num" style={{ textAlign: "right" }}>
                    {money(c.value)}
                  </td>
                  <td className="num" style={{ textAlign: "right" }}>
                    {money(c.total - c.value)}
                  </td>
                  <td style={{ minWidth: 140 }}>
                    <Progress value={c.total ? (c.value / c.total) * 100 : 0} label={`Collection rate for ${c.period}`} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </Page>
  );
}
