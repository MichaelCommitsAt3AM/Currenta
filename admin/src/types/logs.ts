// Hand-written types for /api/admin/logs/* — these endpoints aren't in
// types/api.ts yet because that file is generated from the deployed
// backend's openapi.json (`npm run gen:types`), and the logs endpoints
// haven't shipped to the home server yet. Regenerate and delete this file's
// duplication once they have.

export type LogLevel = 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR' | 'CRITICAL'

export interface LogGroup {
  signature: string
  level: LogLevel
  service: string
  logger: string
  component: string | null
  message_sample: string
  count: number
  first_seen: string
  last_seen: string
}

export interface DependencyHealth {
  name: string
  status: 'ok' | 'warning' | 'error'
  warning_count: number
  error_count: number
  last_seen: string | null
}

export interface LogsOverviewResponse {
  health: DependencyHealth[]
  groups: LogGroup[]
}

export interface LogEntry {
  id: number
  created_at: string
  level: LogLevel
  service: string
  logger: string
  component: string | null
  message: string
  module: string | null
  func: string | null
  line: number | null
  exc_text: string | null
}

export interface LogEntriesResponse {
  entries: LogEntry[]
  next_cursor: string | null
}

export interface LogFacets {
  services: string[]
  loggers: string[]
  components: string[]
  level_counts: Partial<Record<LogLevel, number>>
}
