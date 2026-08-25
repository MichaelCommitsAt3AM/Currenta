import { useQuery } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { LogsOverviewResponse } from '../types/logs'

export function useLogsOverview(token: string, hours: number, live: boolean) {
  return useQuery({
    queryKey: ['admin-logs-overview', hours],
    queryFn: () => adminFetch<LogsOverviewResponse>(`/api/admin/logs/overview?hours=${hours}`, token),
    // Live-tail toggle drives polling here rather than a websocket — the
    // grouped/overview view is cheap to recompute and doesn't need
    // sub-5s latency.
    refetchInterval: live ? 5000 : false,
  })
}
