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

function relativeTime(iso: string | null | undefined): string {
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

      {!isLoading && !isError && (
        <div className="table-wrapper">
          <table className={styles.trendingTable}>
            <thead>
              <tr>
                <th>#</th>
                <th>Article Title</th>
                <th>Source</th>
                <th>Category</th>
                <th>Country</th>
                <th>Trend Score</th>
                <th>Published</th>
              </tr>
            </thead>
            <tbody>
              {articles.length === 0 ? (
                <tr>
                  <td colSpan={7} className={styles.emptyCell}>
                    No trending articles in this window.
                  </td>
                </tr>
              ) : (
                articles.map((article, i) => (
                  <tr key={article.id}>
                    <td className={styles.rankCell}>{i + 1}</td>
                    <td>
                      <a
                        className={styles.titleLink}
                        href={article.original_url ?? undefined}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {article.title}
                      </a>
                      {article.is_major_source && <span className={`badge ${styles.majorBadge}`}>Major source</span>}
                    </td>
                    <td>{article.source_name ?? '—'}</td>
                    <td>
                      {article.categories?.[0] ?? '—'}
                      {article.subcategory && <span className={styles.subcategory}> / {article.subcategory}</span>}
                    </td>
                    <td>{article.country_code ?? '—'}</td>
                    <td className={styles.trendScore}>{article.trend_score.toFixed(1)}</td>
                    <td>{relativeTime(article.published_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
