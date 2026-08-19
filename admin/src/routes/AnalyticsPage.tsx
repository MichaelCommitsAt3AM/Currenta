import { CategoryChart } from '../components/CategoryChart'
import { HealthChart } from '../components/HealthChart'
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
          <div className={styles.kpiIcon}>🤖</div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>AI Messages Today</span>
            <h3>{(data?.ai_usage.messages_today ?? 0).toLocaleString()}</h3>
          </div>
        </div>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>⚡</div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>Quota Saturation</span>
            <h3>{quotaSaturation}%</h3>
          </div>
        </div>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>👥</div>
          <div className={styles.kpiInfo}>
            <span className={styles.kpiLabel}>Total Users</span>
            <h3>{(data?.user_growth.total_users ?? 0).toLocaleString()}</h3>
          </div>
        </div>
        <div className={`glass-card ${styles.kpiCard}`}>
          <div className={styles.kpiIcon}>🗞️</div>
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

      <div className={`glass-card ${styles.tableCard}`}>
        <div className={styles.cardHeader}>
          <h3>Trending Articles (7d)</h3>
          <span className="badge">Trending</span>
        </div>
        <div className="table-wrapper">
          <table className={styles.trendingTable}>
            <thead>
              <tr>
                <th>Article Title</th>
                <th>Trend Score</th>
              </tr>
            </thead>
            <tbody>
              {!data || data.content_engagement.trending.length === 0 ? (
                <tr>
                  <td colSpan={2}>No trending articles in the last 7 days.</td>
                </tr>
              ) : (
                data.content_engagement.trending.map((article, i) => (
                  <tr key={i}>
                    <td>{article.title}</td>
                    <td className={styles.trendScore}>{Number(article.trend_score).toFixed(1)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  )
}
