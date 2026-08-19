import { useState } from 'react'
import { useToast } from '../hooks/useToast'
import { usePublishDraft } from '../hooks/useDraftMutations'
import type { NewsDraft, PublishRequest } from '../types/admin'
import { CategoryChips } from './CategoryChips'
import { CountrySelect } from './CountrySelect'
import styles from './DraftEditor.module.css'
import { ImageField } from './ImageField'

interface Props {
  token: string
  initialData: NewsDraft | null
  originalUrl: string
  onClose: () => void
}

interface FormState {
  title: string
  summary: string
  sourceName: string
  subcategory: string
  countryCode: string | null
  isPaywalled: boolean
  imageUrl: string
  expiresAt: string | null | undefined
  categories: string[]
}

function toFormState(draft: NewsDraft | null): FormState {
  return {
    title: draft?.title ?? '',
    summary: draft?.summary ?? '',
    sourceName: draft?.source_name ?? '',
    subcategory: draft?.subcategory ?? '',
    countryCode: draft?.country_code ?? null,
    isPaywalled: draft?.is_paywalled ?? false,
    imageUrl: draft?.image_url ?? '',
    expiresAt: draft?.expires_at,
    categories: draft?.categories ?? [],
  }
}

function countWords(text: string): number {
  const trimmed = text.trim()
  return trimmed ? trimmed.split(/\s+/).length : 0
}

export function DraftEditor({ token, initialData, originalUrl, onClose }: Props) {
  const [form, setForm] = useState<FormState>(() => toFormState(initialData))
  const [publishError, setPublishError] = useState('')
  const publish = usePublishDraft(token)
  const { showToast } = useToast()

  const wordCount = countWords(form.summary)
  const wordCountOk = wordCount >= 60 && wordCount <= 68

  function toggleCategory(cat: string) {
    setForm((f) => ({
      ...f,
      categories: f.categories.includes(cat) ? f.categories.filter((c) => c !== cat) : [...f.categories, cat],
    }))
  }

  async function handlePublish() {
    if (!form.title || !form.summary || form.categories.length === 0) {
      setPublishError('Title, Summary, and at least one Category are required.')
      return
    }

    const payload: PublishRequest = {
      title: form.title,
      summary: form.summary,
      categories: form.categories,
      subcategory: form.subcategory,
      source_name: form.sourceName,
      original_url: originalUrl || 'manual',
      image_url: form.imageUrl,
      country_code: form.countryCode,
      is_paywalled: form.isPaywalled,
      expires_at: form.expiresAt ?? undefined,
    }

    setPublishError('')
    try {
      await publish.mutateAsync(payload)
      showToast('Article Published Successfully!')
      onClose()
    } catch (err) {
      setPublishError(err instanceof Error ? err.message : 'Publish failed')
    }
  }

  return (
    <section className={styles.editorSection}>
      <div className="glass-card">
        <div className={styles.editorHeader}>
          <h3>Draft Editor</h3>
          {initialData && <span className="badge ai">AI Assisted</span>}
        </div>

        <div className={styles.editorGrid}>
          <div>
            <div className="input-group">
              <label htmlFor="draft-title">Title</label>
              <input
                id="draft-title"
                type="text"
                value={form.title}
                onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              />
            </div>

            <div className="input-group">
              <label htmlFor="draft-summary">AI Summary (60-68 words)</label>
              <textarea
                id="draft-summary"
                rows={5}
                value={form.summary}
                onChange={(e) => setForm((f) => ({ ...f, summary: e.target.value }))}
              />
              <div
                className={styles.wordCount}
                style={{ color: wordCountOk ? 'var(--success-color)' : 'var(--error-color)' }}
              >
                {wordCount} / 68
              </div>
            </div>

            <div className={styles.inputRow}>
              <div className="input-group">
                <label htmlFor="draft-source">Source Name</label>
                <input
                  id="draft-source"
                  type="text"
                  value={form.sourceName}
                  onChange={(e) => setForm((f) => ({ ...f, sourceName: e.target.value }))}
                />
              </div>
              <div className="input-group">
                <label htmlFor="draft-subcategory">Subcategory</label>
                <input
                  id="draft-subcategory"
                  type="text"
                  placeholder="e.g. AI, Space, Politics"
                  value={form.subcategory}
                  onChange={(e) => setForm((f) => ({ ...f, subcategory: e.target.value }))}
                />
              </div>
            </div>

            <div className={styles.inputRow}>
              <div className="input-group">
                <label htmlFor="draft-country">Country</label>
                <CountrySelect
                  value={form.countryCode}
                  onChange={(code) => setForm((f) => ({ ...f, countryCode: code }))}
                />
              </div>
              <div className={`input-group ${styles.toggleGroup}`}>
                <label>Paywalled</label>
                <input
                  type="checkbox"
                  className={styles.toggleInput}
                  checked={form.isPaywalled}
                  onChange={(e) => setForm((f) => ({ ...f, isPaywalled: e.target.checked }))}
                />
              </div>
            </div>
          </div>

          <div>
            <ImageField value={form.imageUrl} onChange={(url) => setForm((f) => ({ ...f, imageUrl: url }))} />

            <div className="input-group">
              <label>Categories</label>
              <CategoryChips selected={form.categories} onToggle={toggleCategory} />
            </div>

            <div>
              <label>Image Preview</label>
              <div className={styles.imageBox}>
                {form.imageUrl ? (
                  <img src={form.imageUrl} alt="Preview" />
                ) : (
                  <span>{initialData ? 'No Image Detected' : 'Manual Preview'}</span>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className={styles.editorFooter}>
          {publishError && <p className="error">{publishError}</p>}
          <button className="btn primary" disabled={publish.isPending} onClick={() => void handlePublish()}>
            {publish.isPending ? <div className="loader" /> : 'Publish to Database'}
          </button>
        </div>
      </div>
    </section>
  )
}
