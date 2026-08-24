import type { components } from './api'

export type NewsDraft = components['schemas']['NewsDraft']
export type PublishRequest = components['schemas']['PublishRequest']
export type SqlQueryResponse = components['schemas']['SqlQueryResponse']
export type AnalyticsOverview = components['schemas']['AnalyticsOverview']
export type PublishResponse = components['schemas']['PublishResponse']

// Hand-written to match backend/api/admin.py's TrendingArticleDetail /
// TrendingArticlesResponse until `npm run gen:types` is re-run against a
// deploy that includes GET /api/admin/trending.
export interface TrendingArticleDetail {
  id: string
  title: string
  source_name: string | null
  original_url: string | null
  image_url: string | null
  categories: string[] | null
  subcategory: string | null
  country_code: string | null
  published_at: string | null
  trend_score: number
  is_major_source: boolean | null
}

export interface TrendingArticlesResponse {
  articles: TrendingArticleDetail[]
}
