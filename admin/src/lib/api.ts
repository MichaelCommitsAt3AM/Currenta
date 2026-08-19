import { config } from './config'

export class AdminApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'AdminApiError'
    this.status = status
  }
}

interface AdminFetchInit extends Omit<RequestInit, 'body'> {
  /** Serialized as the JSON body and sets Content-Type automatically. */
  json?: unknown
}

/**
 * Thin fetch wrapper shared by every /api/admin/* call: injects the bearer
 * token, and on failure surfaces the backend's `detail` message (FastAPI's
 * HTTPException shape) as a typed AdminApiError instead of a generic
 * "Unexpected token" JSON-parse error.
 */
export async function adminFetch<T>(
  path: string,
  token: string,
  init: AdminFetchInit = {},
): Promise<T> {
  const { json, headers, ...rest } = init

  const response = await fetch(`${config.apiBaseUrl}${path}`, {
    ...rest,
    headers: {
      ...(json !== undefined ? { 'Content-Type': 'application/json' } : {}),
      Authorization: `Bearer ${token}`,
      ...headers,
    },
    body: json !== undefined ? JSON.stringify(json) : undefined,
  })

  if (!response.ok) {
    let detail = ''
    try {
      const body = await response.json()
      detail = body?.detail || ''
    } catch {
      detail = ''
    }
    throw new AdminApiError(detail || `Server returned ${response.status}`, response.status)
  }

  const text = await response.text()
  return (text ? JSON.parse(text) : undefined) as T
}
