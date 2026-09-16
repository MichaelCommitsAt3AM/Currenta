import { useQuery } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { BillingTrendsResponse } from '../types/admin'

export function useBilling(token: string, days: number) {
  return useQuery({
    queryKey: ['admin-billing', days],
    queryFn: () => adminFetch<BillingTrendsResponse>(`/api/admin/billing/trends?days=${days}`, token),
  })
}
