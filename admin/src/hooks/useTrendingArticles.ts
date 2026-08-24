import { useQuery } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { TrendingArticlesResponse } from '../types/admin'

interface Filters {
  country: string | null
  hours: number
}

export function useTrendingArticles(token: string, { country, hours }: Filters) {
  return useQuery({
    queryKey: ['admin-trending', country, hours],
    queryFn: () => {
      const params = new URLSearchParams({ hours: String(hours), limit: '50' })
      if (country) params.set('country', country)
      return adminFetch<TrendingArticlesResponse>(`/api/admin/trending?${params}`, token)
    },
  })
}
