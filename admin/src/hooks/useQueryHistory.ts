import { useCallback, useEffect, useState } from 'react'

const STORAGE_KEY = 'currenta_admin_query_history'
const MAX_ENTRIES = 25

export interface QueryHistoryEntry {
  id: string
  sql: string
  ranAt: number
}

function load(): QueryHistoryEntry[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

export function useQueryHistory() {
  const [entries, setEntries] = useState<QueryHistoryEntry[]>(load)

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(entries))
    } catch {
      // localStorage unavailable (private mode, quota) — history just won't persist
    }
  }, [entries])

  const add = useCallback((sql: string) => {
    setEntries((prev) => {
      const deduped = prev.filter((entry) => entry.sql !== sql)
      const next: QueryHistoryEntry = { id: crypto.randomUUID(), sql, ranAt: Date.now() }
      return [next, ...deduped].slice(0, MAX_ENTRIES)
    })
  }, [])

  const remove = useCallback((id: string) => {
    setEntries((prev) => prev.filter((entry) => entry.id !== id))
  }, [])

  const clear = useCallback(() => setEntries([]), [])

  return { entries, add, remove, clear }
}
