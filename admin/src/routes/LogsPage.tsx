import { useEffect, useState } from 'react'
import { RecordDetailPanel } from '../components/RecordDetailPanel'
import { useLogEntries } from '../hooks/useLogEntries'
import { useLogFacets } from '../hooks/useLogFacets'
import { useLogsOverview } from '../hooks/useLogsOverview'
import type { LogEntry, LogGroup } from '../types/logs'
import styles from './LogsPage.module.css'

interface Props {
  token: string
}

const WINDOW_OPTIONS = [
  { hours: 1, label: 'Last hour' },
  { hours: 24, label: 'Last 24 hours' },
  { hours: 72, label: 'Last 3 days' },
  { hours: 168, label: 'Last 7 days' },
]

function relativeTime(iso: string | null | undefined): string {
  if (!iso) return '—'
  const diffMs = Date.now() - new Date(iso).getTime()
  const seconds = Math.round(diffMs / 1000)
  if (seconds < 60) return `${Math.max(seconds, 0)}s ago`
  const minutes = Math.round(seconds / 60)
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.round(hours / 24)
  return `${days}d ago`
}

function useDebounced(value: string, delayMs = 300): string {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(value), delayMs)
    return () => window.clearTimeout(timer)
  }, [value, delayMs])
  return debounced
}

function levelClass(level: string): string {
  switch (level) {
    case 'ERROR':
    case 'CRITICAL':
      return styles.levelError
    case 'WARNING':
      return styles.levelWarning
    default:
      return styles.levelInfo
  }
}

export function LogsPage({ token }: Props) {
  const [hours, setHours] = useState(24)
  const [tab, setTab] = useState<'errors' | 'raw'>('raw')
  const [live, setLive] = useState(false)

  const [level, setLevel] = useState('')
  const [service, setService] = useState('')
  const [component, setComponent] = useState('')
  const [loggerFilter, setLoggerFilter] = useState('')
  const [searchInput, setSearchInput] = useState('')
  const q = useDebounced(searchInput)

  const [drillSignature, setDrillSignature] = useState<string | null>(null)
  const [selectedEntry, setSelectedEntry] = useState<LogEntry | null>(null)

  const overview = useLogsOverview(token, hours, live && tab === 'errors')
  const facets = useLogFacets(token, hours)
  const rawTailActive = live && (tab === 'raw' || drillSignature !== null)
  const entries = useLogEntries(
    token,
    {
      hours,
      level: level || null,
      service: service || null,
      component: component || null,
      logger: loggerFilter || null,
      q,
      signature: drillSignature,
    },
    rawTailActive,
  )

  const groups = overview.data?.groups ?? []
  const health = overview.data?.health ?? []
  const allEntries = entries.data?.pages.flatMap((p) => p.entries) ?? []

  function drillIntoGroup(group: LogGroup) {
    setDrillSignature(group.signature)
    setSelectedEntry(null)
    setTab('raw')
  }

  function clearDrilldown() {
    setDrillSignature(null)
  }

  return (
    <section className="tab-content">
      <div className="section-header">
        <h2>Backend Logs</h2>
        <p>Application logs from the api and worker services — WARNING and above, plus key job-lifecycle events.</p>
      </div>

      {health.length > 0 && (
        <div className={styles.healthStrip}>
          {health.map((dep) => (
            <div key={dep.name} className={`${styles.healthCard} ${styles[`health_${dep.status}`]}`}>
              <div className={styles.healthName}>{dep.name}</div>
              <div className={styles.healthCounts}>
                {dep.error_count > 0 && <span className={styles.healthError}>{dep.error_count} err</span>}
                {dep.warning_count > 0 && <span className={styles.healthWarning}>{dep.warning_count} warn</span>}
              </div>
              <div className={styles.healthLastSeen}>{relativeTime(dep.last_seen)}</div>
            </div>
          ))}
        </div>
      )}

      <div className={`glass-card ${styles.filtersCard}`}>
        <div className={styles.tabs}>
          <button
            className={`${styles.tabButton} ${tab === 'raw' ? styles.tabActive : ''}`}
            onClick={() => setTab('raw')}
          >
            Raw Entries
          </button>
          <button
            className={`${styles.tabButton} ${tab === 'errors' ? styles.tabActive : ''}`}
            onClick={() => setTab('errors')}
          >
            Grouped Errors
          </button>
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

        {tab === 'raw' && (
          <>
            <div className={styles.filterField}>
              <label>Level</label>
              <select value={level} onChange={(e) => setLevel(e.target.value)}>
                <option value="">Any</option>
                <option value="WARNING">Warning+</option>
                <option value="ERROR">Error+</option>
              </select>
            </div>
            <div className={styles.filterField}>
              <label>Service</label>
              <select value={service} onChange={(e) => setService(e.target.value)}>
                <option value="">Any</option>
                {(facets.data?.services ?? []).map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            </div>
            <div className={styles.filterField}>
              <label>Component</label>
              <select value={component} onChange={(e) => setComponent(e.target.value)}>
                <option value="">Any</option>
                {(facets.data?.components ?? []).map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </div>
            <div className={styles.filterField}>
              <label>Logger</label>
              <select value={loggerFilter} onChange={(e) => setLoggerFilter(e.target.value)}>
                <option value="">Any</option>
                {(facets.data?.loggers ?? []).map((l) => (
                  <option key={l} value={l}>
                    {l}
                  </option>
                ))}
              </select>
            </div>
            <div className={styles.filterField}>
              <label>Search</label>
              <input
                type="text"
                placeholder="Search message..."
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
              />
            </div>
          </>
        )}

        <label className={styles.liveToggle}>
          <input type="checkbox" checked={live} onChange={(e) => setLive(e.target.checked)} />
          Live
        </label>
      </div>

      {tab === 'raw' && drillSignature && (
        <div className={styles.drillBanner}>
          Filtered to one error signature.
          <button className="btn outline" onClick={clearDrilldown}>
            Clear
          </button>
        </div>
      )}

      {tab === 'errors' && (
        <>
          {overview.isLoading && (
            <div className={styles.loadingState}>
              <div className="loader-large" />
            </div>
          )}
          {overview.isError && <div className="error">Failed to load logs overview</div>}
          {!overview.isLoading && !overview.isError && (
            <div className="table-wrapper">
              <table className={styles.logTable}>
                <thead>
                  <tr>
                    <th>Level</th>
                    <th>Component</th>
                    <th>Message</th>
                    <th>Count</th>
                    <th>First seen</th>
                    <th>Last seen</th>
                  </tr>
                </thead>
                <tbody>
                  {groups.length === 0 ? (
                    <tr>
                      <td colSpan={6} className={styles.emptyCell}>
                        No warnings or errors in this window.
                      </td>
                    </tr>
                  ) : (
                    groups.map((group) => (
                      <tr key={group.signature} className={styles.clickableRow} onClick={() => drillIntoGroup(group)}>
                        <td>
                          <span className={`badge ${levelClass(group.level)}`}>{group.level}</span>
                        </td>
                        <td>{group.component ?? group.logger}</td>
                        <td className={styles.messageCell} title={group.message_sample}>
                          {group.message_sample}
                        </td>
                        <td className={styles.countCell}>{group.count}</td>
                        <td>{relativeTime(group.first_seen)}</td>
                        <td>{relativeTime(group.last_seen)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}

      {tab === 'raw' && (
        <div className={styles.rawLayout}>
          <div className={styles.rawTableColumn}>
            {entries.isLoading && (
              <div className={styles.loadingState}>
                <div className="loader-large" />
              </div>
            )}
            {entries.isError && <div className="error">Failed to load log entries</div>}
            {!entries.isLoading && !entries.isError && (
              <>
                <div className="table-wrapper">
                  <table className={styles.logTable}>
                    <thead>
                      <tr>
                        <th>Time</th>
                        <th>Level</th>
                        <th>Service</th>
                        <th>Component / Logger</th>
                        <th>Message</th>
                      </tr>
                    </thead>
                    <tbody>
                      {allEntries.length === 0 ? (
                        <tr>
                          <td colSpan={5} className={styles.emptyCell}>
                            No log entries match these filters.
                          </td>
                        </tr>
                      ) : (
                        allEntries.map((entry) => (
                          <tr
                            key={entry.id}
                            className={styles.clickableRow}
                            onClick={() => setSelectedEntry(entry)}
                          >
                            <td className={styles.timeCell}>{relativeTime(entry.created_at)}</td>
                            <td>
                              <span className={`badge ${levelClass(entry.level)}`}>{entry.level}</span>
                            </td>
                            <td>{entry.service}</td>
                            <td>{entry.component ?? entry.logger}</td>
                            <td className={styles.messageCell} title={entry.message}>
                              {entry.message}
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
                {entries.hasNextPage && (
                  <button
                    className="btn outline"
                    onClick={() => entries.fetchNextPage()}
                    disabled={entries.isFetchingNextPage}
                  >
                    {entries.isFetchingNextPage ? 'Loading…' : 'Load more'}
                  </button>
                )}
              </>
            )}
          </div>

          {selectedEntry && (
            <RecordDetailPanel record={selectedEntry as unknown as Record<string, unknown>} onClose={() => setSelectedEntry(null)} />
          )}
        </div>
      )}
    </section>
  )
}
