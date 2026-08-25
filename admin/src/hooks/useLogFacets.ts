import { useQuery } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { LogFacets } from '../types/logs'

export function useLogFacets(token: string, hours: number) {
  return useQuery({
    queryKey: ['admin-log-facets', hours],
    queryFn: () => adminFetch<LogFacets>(`/api/admin/logs/facets?hours=${hours}`, token),
  })
}
