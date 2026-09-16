import { useState } from 'react'
import { BillingTrendChart } from '../components/BillingTrendChart'
import { DollarSignIcon } from '../components/icons'
import { useBilling } from '../hooks/useBilling'
import styles from './BillingPage.module.css'

const DAY_OPTIONS = [
  { days: 7, label: 'Last 7 days' },
  { days: 30, label: 'Last 30 days' },
  { days: 90, label: 'Last 90 days' },
]

interface Props {
  token: string
}

export function BillingPage({ token }: Props) {
  const [days, setDays] = useState(30)
  const { data, isLoading, error } = useBilling(token, days)

  const dailyAverage = data && data.daily.length > 0 ? data.total_cost / data.daily.length : 0
  const topService = data?.by_service[0]

  return (
    <section className="tab-content">
      <div className="section-header">
        <h2>GCP Billing</h2>
        <p>Cost trends from the Billing Export BigQuery table.</p>
      </div>

      <div className={styles.filterField}>
        <label>Window</label>
        <select value={days} onChange={(e) => setDays(Number(e.target.value))}>
          {DAY_OPTIONS.map((opt) => (
            <option key={opt.days} value={opt.days}>
              {opt.label}
            </option>
          ))}
        </select>
      </div>

      {error && (
        <div className={`glass-card ${styles.errorCard}`}>
          Failed to load billing data: {error instanceof Error ? error.message : 'Unknown error'}.
          Confirm BIGQUERY_BILLING_TABLE / GOOGLE_APPLICATION_CREDENTIALS are configured on the backend.
        </div>
      )}

      {!error && (
        <>
          <div className={styles.billingGrid}>
            <div className={`glass-card ${styles.kpiCard}`}>
              <div className={styles.kpiIcon}>
                <DollarSignIcon />
              </div>
              <div className={styles.kpiInfo}>
                <span className={styles.kpiLabel}>Total Cost ({days}d)</span>
                <h3>{formatCost(data?.total_cost, data?.currency)}</h3>
              </div>
            </div>
            <div className={`glass-card ${styles.kpiCard}`}>
              <div className={styles.kpiIcon}>
                <DollarSignIcon />
              </div>
              <div className={styles.kpiInfo}>
                <span className={styles.kpiLabel}>Daily Average</span>
                <h3>{formatCost(dailyAverage, data?.currency)}</h3>
              </div>
            </div>
            <div className={`glass-card ${styles.kpiCard}`}>
              <div className={styles.kpiIcon}>
                <DollarSignIcon />
              </div>
              <div className={styles.kpiInfo}>
                <span className={styles.kpiLabel}>Top Service</span>
                <h3 className={styles.topService}>{topService?.service ?? (isLoading ? '…' : '—')}</h3>
              </div>
            </div>
          </div>

          <div className={`glass-card ${styles.chartCard}`}>
            <h3>Daily Cost</h3>
            <div className={styles.chartWrapper}>
              {data && <BillingTrendChart data={data.daily} currency={data.currency} />}
            </div>
          </div>

          <div className={`glass-card ${styles.chartCard}`}>
            <h3>Cost by Service</h3>
            <table className={styles.serviceTable}>
              <thead>
                <tr>
                  <th>Service</th>
                  <th>Cost</th>
                </tr>
              </thead>
              <tbody>
                {data?.by_service.map((row) => (
                  <tr key={row.service}>
                    <td>{row.service}</td>
                    <td>{formatCost(row.cost, data.currency)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </section>
  )
}

function formatCost(amount: number | undefined, currency: string | undefined): string {
  if (amount === undefined || currency === undefined) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount)
}
