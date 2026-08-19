import { useMutation } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { SqlQueryResponse } from '../types/admin'

export function useAdminQuery(token: string) {
  return useMutation({
    mutationFn: (query: string) =>
      adminFetch<SqlQueryResponse>('/api/admin/query', token, { method: 'POST', json: { query } }),
  })
}
