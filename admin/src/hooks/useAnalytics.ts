import { useQuery } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { AnalyticsOverview } from '../types/admin'

export function useAnalytics(token: string) {
  return useQuery({
    queryKey: ['admin-analytics'],
    queryFn: () => adminFetch<AnalyticsOverview>('/api/admin/analytics/overview', token),
  })
}
