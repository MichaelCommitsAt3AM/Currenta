import { useState } from 'react'
import { DraftEditor } from '../components/DraftEditor'
import { useGenerateDraft } from '../hooks/useDraftMutations'
import type { NewsDraft } from '../types/admin'
import styles from './IngestionPage.module.css'

interface Props {
  token: string
}

export function IngestionPage({ token }: Props) {
  const [newsUrl, setNewsUrl] = useState('')
  const [editor, setEditor] = useState<{ data: NewsDraft | null } | null>(null)
  const generateDraft = useGenerateDraft(token)

  async function handleGenerateDraft() {
    if (!newsUrl) return
    try {
      const draft = await generateDraft.mutateAsync(newsUrl)
      setEditor({ data: draft })
    } catch (err) {
      alert('Error: ' + (err instanceof Error ? err.message : String(err)))
    }
  }

  function handleManualEntry() {
    setNewsUrl('')
    setEditor({ data: null })
  }

  return (
    <section className="tab-content">
      <div className="section-header">
        <h2>Manual Ingestion</h2>
        <p>Provide a URL to start the magic draft process.</p>
      </div>

      <div className={styles.urlBar}>
        <input
          type="url"
          placeholder="https://niche-news-source.com/article-path"
          value={newsUrl}
          onChange={(e) => setNewsUrl(e.target.value)}
        />
        <button className="btn accent" disabled={generateDraft.isPending} onClick={() => void handleGenerateDraft()}>
          {generateDraft.isPending ? <div className="loader" /> : 'Generate Draft'}
        </button>
        <button className="btn outline" onClick={handleManualEntry}>
          Manual Entry
        </button>
      </div>

      {editor && (
        <DraftEditor token={token} initialData={editor.data} originalUrl={newsUrl} onClose={() => setEditor(null)} />
      )}
    </section>
  )
}
