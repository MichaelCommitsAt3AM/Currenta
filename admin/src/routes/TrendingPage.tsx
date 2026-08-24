import { useState } from 'react'
import { CountrySelect } from '../components/CountrySelect'
import { useTrendingArticles } from '../hooks/useTrendingArticles'
import styles from './TrendingPage.module.css'

interface Props {
  token: string
}

const WINDOW_OPTIONS = [
  { hours: 24, label: 'Last 24 hours' },
  { hours: 72, label: 'Last 3 days' },
  { hours: 168, label: 'Last 7 days' },
  { hours: 720, label: 'Last 30 days' },
]

function relativeTime(iso: string | null): string {
  if (!iso) return '—'
  const diffMs = Date.now() - new Date(iso).getTime()
  const minutes = Math.round(diffMs / 60_000)
  if (minutes < 60) return `${Math.max(minutes, 0)}m ago`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.round(hours / 24)
  return `${days}d ago`
}

export function TrendingPage({ token }: Props) {
  const [country, setCountry] = useState<string | null>(null)
  const [hours, setHours] = useState(168)
  const { data, isLoading, isError, error } = useTrendingArticles(token, { country, hours })

  const articles = data?.articles ?? []

  return (
    <section className="tab-content">
      <div className="section-header">
        <h2>Trending Articles</h2>
        <p>Live-ranked by trend score across the ingested catalog.</p>
      </div>

      <div className={`glass-card ${styles.filtersCard}`}>
        <div className={styles.filterField}>
          <label>Country</label>
          <CountrySelect value={country} onChange={setCountry} />
        </div>
        <div className={styles.filterField}>
          <label>Window</label>
          <select value={hours} onChange={(e) => setHours(Number(e.target.value))}>
            {WINDOW_OPTIONS.map((opt) => (
              <option key={opt.hours} value={opt.hours}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
        <span className={`badge ${styles.countBadge}`}>{articles.length} articles</span>
      </div>

      {isLoading && (
        <div className={styles.loadingState}>
          <div className="loader-large" />
        </div>
      )}

      {isError && <div className="error">{error instanceof Error ? error.message : 'Failed to load trending articles'}</div>}

      {!isLoading && !isError && articles.length === 0 && (
        <div className={`glass-card ${styles.emptyState}`}>No trending articles in this window.</div>
      )}

      {!isLoading && articles.length > 0 && (
        <div className={styles.grid}>
          {articles.map((article) => (
            <a
              key={article.id}
              className={`glass-card ${styles.card}`}
              href={article.original_url ?? undefined}
              target="_blank"
              rel="noreferrer"
            >
              <div className={styles.thumb}>
                {article.image_url ? (
                  <img src={article.image_url} alt="" loading="lazy" />
                ) : (
                  <div className={styles.thumbFallback}>📰</div>
                )}
                <span className={styles.trendScore}>🔥 {article.trend_score.toFixed(1)}</span>
              </div>
              <div className={styles.cardBody}>
                <h3>{article.title}</h3>
                <div className={styles.cardMeta}>
                  <span>{article.source_name ?? 'Unknown source'}</span>
                  <span>·</span>
                  <span>{relativeTime(article.published_at)}</span>
                </div>
                <div className={styles.cardTags}>
                  {article.categories?.[0] && <span className="badge">{article.categories[0]}</span>}
                  {article.country_code && <span className="badge">{article.country_code}</span>}
                  {article.is_major_source && <span className="badge">Major source</span>}
                </div>
              </div>
            </a>
          ))}
        </div>
      )}
    </section>
  )
}
