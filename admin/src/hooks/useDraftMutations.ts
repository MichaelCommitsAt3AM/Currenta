import { useMutation } from '@tanstack/react-query'
import { adminFetch } from '../lib/api'
import type { NewsDraft, PublishRequest, PublishResponse } from '../types/admin'

export function useGenerateDraft(token: string) {
  return useMutation({
    mutationFn: (url: string) =>
      adminFetch<NewsDraft>('/api/admin/news/draft', token, { method: 'POST', json: { url } }),
  })
}

export function usePublishDraft(token: string) {
  return useMutation({
    mutationFn: (payload: PublishRequest) =>
      adminFetch<PublishResponse>('/api/admin/news/publish', token, { method: 'POST', json: payload }),
  })
}
