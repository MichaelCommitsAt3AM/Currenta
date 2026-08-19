import { useState } from 'react'
import styles from './RecordDetailPanel.module.css'

interface Props {
  record: Record<string, unknown>
  onClose: () => void
}

function TruncatedText({ text }: { text: string }) {
  const [expanded, setExpanded] = useState(false)
  return (
    <div
      className={`${styles.truncatedText} ${expanded ? styles.expanded : ''}`}
      title="Click to expand"
      onClick={() => setExpanded((e) => !e)}
    >
      {text}
    </div>
  )
}

function DetailValue({ value }: { value: unknown }) {
  if (value === null) return <i>null</i>

  if (Array.isArray(value) && value.length > 20) {
    const preview = value.slice(0, 5).map((v) => (typeof v === 'number' ? v.toFixed(4) : String(v)))
    return (
      <div className={styles.truncatedArray}>
        [{preview.join(', ')}, ... <span className="badge small">{value.length} items total</span>]
      </div>
    )
  }

  if (typeof value === 'object') {
    return <pre>{JSON.stringify(value, null, 2)}</pre>
  }

  if (typeof value === 'string' && (value.startsWith('http://') || value.startsWith('https://'))) {
    return (
      <a href={value} target="_blank" rel="noopener noreferrer" className={styles.accentLink}>
        {value}
      </a>
    )
  }

  if (typeof value === 'string' && value.length > 500) {
    return <TruncatedText text={value} />
  }

  return <>{String(value)}</>
}

export function RecordDetailPanel({ record, onClose }: Props) {
  return (
    <div className={styles.detailPanel}>
      <div className={styles.detailPanelHeader}>
        <h3>Record Details</h3>
        <button className="btn outline" onClick={onClose}>
          ✕
        </button>
      </div>
      <div className={styles.detailContent}>
        {Object.entries(record).map(([key, value]) => (
          <div key={key} className={styles.detailItem}>
            <div className={styles.detailLabel}>{key}</div>
            <div className={styles.detailValue}>
              <DetailValue value={value} />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
