import type { components } from './api'

export type NewsDraft = components['schemas']['NewsDraft']
export type PublishRequest = components['schemas']['PublishRequest']
export type SqlQueryResponse = components['schemas']['SqlQueryResponse']
export type AnalyticsOverview = components['schemas']['AnalyticsOverview']
export type PublishResponse = components['schemas']['PublishResponse']
export type TrendingArticleDetail = components['schemas']['TrendingArticleDetail']
export type TrendingArticlesResponse = components['schemas']['TrendingArticlesResponse']

// Backend added this after api.ts was last generated — run `npm run gen:types`
// once /api/admin/billing/trends is deployed, then switch this to
// components['schemas']['BillingTrendsResponse'] like the others above.
export interface BillingTrendsResponse {
  currency: string
  total_cost: number
  daily: { date: string; cost: number }[]
  by_service: { service: string; cost: number }[]
}
