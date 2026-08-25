import { useInfiniteQuery } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { LogEntriesResponse } from '../types/logs'

export interface LogEntryFilters {
  hours: number
  level: string | null
  service: string | null
  component: string | null
  logger: string | null
  q: string
  signature: string | null
}

export function useLogEntries(token: string, filters: LogEntryFilters, live: boolean) {
  return useInfiniteQuery({
    queryKey: ['admin-log-entries', filters],
    queryFn: ({ pageParam }: { pageParam: string | null }) => {
      const params = new URLSearchParams({ hours: String(filters.hours), limit: '100' })
      if (filters.level) params.set('level', filters.level)
      if (filters.service) params.set('service', filters.service)
      if (filters.component) params.set('component', filters.component)
      if (filters.logger) params.set('logger', filters.logger)
      if (filters.q) params.set('q', filters.q)
      if (filters.signature) params.set('signature', filters.signature)
      if (pageParam) params.set('cursor', pageParam)
      return adminFetch<LogEntriesResponse>(`/api/admin/logs/entries?${params}`, token)
    },
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => lastPage.next_cursor,
    // react-query refetches every already-loaded page on each interval tick
    // (not just the first), to keep the cursor chain consistent — so
    // live-tail cost scales with how far the admin has scrolled. Acceptable
    // here since raw entries are meant for short drill-down sessions, not
    // deep scrollback; the grouped overview (useLogsOverview) is the surface
    // meant to stay open and polling long-term.
    refetchInterval: live ? 5000 : false,
  })
}
