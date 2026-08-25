import { CategoryChart } from '../components/CategoryChart'
import { HealthChart } from '../components/HealthChart'
import { CpuIcon, NewspaperIcon, UsersIcon, ZapIcon } from '../components/icons'
import { useAnalytics } from '../hooks/useAnalytics'
import styles from './AnalyticsPage.module.css'

interface Props {
  token: string
}

export function AnalyticsPage({ token }: Props) {
  const { data } = useAnalytics(token)

  const quotaSaturation =
    data && data.user_growth.total_users > 0
      ? Math.round((data.ai_usage.quota_users / data.user_growth.total_users) * 100)
      : 0

  return (
    <section className="tab-content">
      <div className="section-header">
        <h2>Insights &amp; Analytics</h2>
        <p>Real-time performance metrics for AI usage and content engagement.</p>
      </div>

      <div className={styles.analyticsGrid}>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>
            <CpuIcon />
          </div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>AI Messages Today</span>
            <h3>{(data?.ai_usage.messages_today ?? 0).toLocaleString()}</h3>
          </div>
        </div>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>
            <ZapIcon />
          </div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>Quota Saturation</span>
            <h3>{quotaSaturation}%</h3>
          </div>
        </div>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>
            <UsersIcon />
          </div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>Total Users</span>
            <h3>{(data?.user_growth.total_users ?? 0).toLocaleString()}</h3>
          </div>
        </div>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>
            <NewspaperIcon />
          </div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>News Generated</span>
            <h3>{(data?.ai_usage.news_generations_today ?? 0).toLocaleString()}</h3>
          </div>
        </div>
      </div>

      <div className={styles.chartsContainer}>
        <div className={`glass-card ${styles.chartCard}`}>
          <h3>Category Distribution</h3>
          <div className={styles.chartWrapper}>
            {data && <CategoryChart data={data.content_engagement.category_distribution} />}
          </div>
        </div>
        <div className={`glass-card ${styles.chartCard}`}>
          <h3>Ingestion Health (24h)</h3>
          <div className={styles.chartWrapper}>{data && <HealthChart data={data.ingestion_health} />}</div>
        </div>
      </div>
    </section>
  )
}
