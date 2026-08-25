import { useRef, useState } from 'react'
import { QueryHistoryPanel } from '../components/QueryHistoryPanel'
import { RecordDetailPanel } from '../components/RecordDetailPanel'
import { ResultsTable } from '../components/ResultsTable'
import { useAdminQuery } from '../hooks/useAdminQuery'
import { useQueryHistory } from '../hooks/useQueryHistory'
import type { SqlQueryResponse } from '../types/admin'
import styles from './QueryExplorerPage.module.css'

interface Props {
  token: string
}

type Row = Record<string, unknown>

function downloadCsv(results: SqlQueryResponse) {
  if (results.data.length === 0) return

  const cols = results.columns
  const csvContent = [
    cols.join(','),
    ...results.data.map((row) =>
      cols
        .map((c) => {
          const val = (row as Row)[c]
          if (val === null || val === undefined) return ''
          const str = String(val).replace(/"/g, '""')
          return str.includes(',') || str.includes('\n') || str.includes('"') ? `"${str}"` : str
        })
        .join(','),
    ),
  ].join('\n')

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.setAttribute('href', url)
  link.setAttribute('download', `query_results_${Date.now()}.csv`)
  link.style.visibility = 'hidden'
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

export function QueryExplorerPage({ token }: Props) {
  const [sql, setSql] = useState('')
  const [results, setResults] = useState<SqlQueryResponse | null>(null)
  const [selectedRow, setSelectedRow] = useState<Row | null>(null)
  const [queryError, setQueryError] = useState('')
  const runQuery = useAdminQuery(token)
  const history = useQueryHistory()
  const sqlTextareaRef = useRef<HTMLTextAreaElement>(null)

  async function handleRunQuery() {
    const trimmed = sql.trim()
    if (!trimmed) return
    setQueryError('')
    try {
      const data = await runQuery.mutateAsync(trimmed)
      setResults(data)
      setSelectedRow(null)
      history.add(trimmed)
    } catch (err) {
      setQueryError(err instanceof Error ? err.message : 'Query failed')
    }
  }

  function handleClear() {
    setSql('')
    setResults(null)
    setQueryError('')
    setSelectedRow(null)
  }

  function handleSelectHistory(historicalSql: string) {
    setSql(historicalSql)
    sqlTextareaRef.current?.focus()
  }

  return (
    <section className={`tab-content ${styles.querySection}`}>
      <div className="section-header">
        <h2>Database Explorer</h2>
        <p>Run read-only SQL queries to inspect the system state. (Capped to 100 rows)</p>
      </div>

      <div className={`glass-card ${styles.queryCard}`}>
        <div className={styles.queryEditorLayout}>
          <div className={styles.queryEditorMain}>
            <textarea
              ref={sqlTextareaRef}
              className={styles.sqlQuery}
              placeholder="SELECT * FROM articles WHERE published_at > NOW() - INTERVAL '24 hours' ORDER BY ranking_score DESC;"
              value={sql}
              onChange={(e) => setSql(e.target.value)}
            />
            <div className={styles.queryActions}>
              <button className="btn primary" disabled={runQuery.isPending} onClick={() => void handleRunQuery()}>
                {runQuery.isPending ? <div className="loader" /> : 'Execute SQL'}
              </button>
              <button className="btn outline" onClick={handleClear}>
                Clear
              </button>
            </div>

            {queryError && <div className="error">{queryError}</div>}
          </div>

          <QueryHistoryPanel
            entries={history.entries}
            onSelect={handleSelectHistory}
            onRemove={history.remove}
            onClear={history.clear}
          />
        </div>

        {results && (
          <div className={styles.resultsContainer}>
            <div className={styles.resultsHeader}>
              <span className="badge">{results.row_count} rows</span>
              <button className="btn outline" onClick={() => downloadCsv(results)}>
                Download CSV
              </button>
            </div>

            <div className={styles.queryContentLayout}>
              <ResultsTable
                columns={results.columns}
                data={results.data as Row[]}
                selectedRow={selectedRow}
                onRowClick={setSelectedRow}
              />

              {selectedRow && <RecordDetailPanel record={selectedRow} onClose={() => setSelectedRow(null)} />}
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
