import type { QueryHistoryEntry } from '../hooks/useQueryHistory'
import { ClockIcon, TrashIcon, XIcon } from './icons'
import styles from './QueryHistoryPanel.module.css'

interface Props {
  entries: QueryHistoryEntry[]
  onSelect: (sql: string) => void
  onRemove: (id: string) => void
  onClear: () => void
}

function formatRelativeTime(ranAt: number): string {
  const minutes = Math.floor((Date.now() - ranAt) / 60000)
  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}

export function QueryHistoryPanel({ entries, onSelect, onRemove, onClear }: Props) {
  return (
    <div className={styles.historyPanel}>
      <div className={styles.historyHeader}>
        <span className={styles.historyTitle}>
          <ClockIcon />
          Recent Queries
        </span>
        {entries.length > 0 && (
          <button type="button" className={styles.clearAll} onClick={onClear} title="Clear history">
            <TrashIcon />
          </button>
        )}
      </div>

      {entries.length === 0 ? (
        <p className={styles.emptyState}>Queries you run will show up here.</p>
      ) : (
        <ul className={styles.historyList}>
          {entries.map((entry) => (
            <li key={entry.id} className={styles.historyItem}>
              <button
                type="button"
                className={styles.historyEntryButton}
                onClick={() => onSelect(entry.sql)}
                title={entry.sql}
              >
                <span className={styles.historySql}>{entry.sql}</span>
                <span className={styles.historyTime}>{formatRelativeTime(entry.ranAt)}</span>
              </button>
              <button
                type="button"
                className={styles.historyRemove}
                onClick={() => onRemove(entry.id)}
                title="Remove from history"
              >
                <XIcon />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
