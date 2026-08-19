import { useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import styles from './ImageField.module.css'

interface Props {
  value: string
  onChange: (url: string) => void
}

export function ImageField({ value, onChange }: Props) {
  const [uploading, setUploading] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return

    setUploading(true)
    try {
      const fileExt = file.name.split('.').pop()
      const fileName = `${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`
      const filePath = `manual-uploads/${fileName}`

      const { error } = await supabase.storage.from('article-images').upload(filePath, file)
      if (error) throw error

      const {
        data: { publicUrl },
      } = supabase.storage.from('article-images').getPublicUrl(filePath)

      onChange(publicUrl)
    } catch (err) {
      console.error('Upload error:', err)
      alert('Upload failed: ' + (err instanceof Error ? err.message : String(err)))
    } finally {
      setUploading(false)
      e.target.value = ''
    }
  }

  return (
    <div className="input-group">
      <label>Image</label>
      <div className={styles.imageInputWrapper}>
        <input type="url" placeholder="https://..." value={value} onChange={(e) => onChange(e.target.value)} />
        <div className={styles.fileUploadBtn}>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className={styles.hiddenFileInput}
            onChange={(e) => void handleFileChange(e)}
          />
          <button type="button" className="btn outline" disabled={uploading}>
            {uploading ? 'Uploading...' : 'Upload'}
          </button>
        </div>
      </div>
    </div>
  )
}
