import { AdminApiError, adminFetch } from './api'
import { supabase } from './supabase'

/**
 * Backward compatibility for older backend deployments that lack
 * /api/admin/session/check: proves the bearer token is accepted by hitting
 * a real admin route with a URL that will fail scraping. Any response other
 * than 401/403/404/5xx still proves the token was accepted, so it counts as
 * success — the probe's own validation error is irrelevant.
 */
async function verifyAdminViaLegacyProbe(token: string): Promise<true> {
  try {
    await adminFetch('/api/admin/news/draft', token, {
      method: 'POST',
      json: { url: 'https://example.invalid/admin-auth-probe' },
    })
  } catch (err) {
    if (err instanceof AdminApiError) {
      if (err.status === 401 || err.status === 403) {
        throw new Error('Access denied: this account is not an admin.')
      }
      if (err.status === 404) {
        throw new Error('Admin API not found on backend deployment (/api/admin/*).')
      }
      if (err.status >= 500) {
        throw new Error('Admin backend is reachable but currently unhealthy.')
      }
    } else {
      throw err
    }
  }
  return true
}

interface SessionCheckResponse {
  ok: boolean
  user_id: string
  email: string
}

/**
 * Verifies the current Supabase session belongs to an admin.
 *   true  — verified, safe to show the dashboard
 *   false — definitively denied (already signed out)
 *   null  — transient failure (network/5xx) — caller should offer retry
 */
export async function enforceAdminSession(
  token: string,
  onEmail: (email: string) => void,
  onError: (message: string, showRetry: boolean) => void,
): Promise<boolean | null> {
  try {
    let data: SessionCheckResponse
    try {
      data = await adminFetch<SessionCheckResponse>('/api/admin/session/check', token)
    } catch (err) {
      if (err instanceof AdminApiError && (err.status === 401 || err.status === 403)) {
        await supabase.auth.signOut()
        onError('Access denied: this account is not an admin.', false)
        return false
      }
      if (err instanceof AdminApiError && err.status === 404) {
        await verifyAdminViaLegacyProbe(token)
        return true
      }
      if (err instanceof AdminApiError) {
        throw new Error(err.message || `Server returned ${err.status}`)
      }
      throw err
    }

    if (data.email) onEmail(data.email)
    return true
  } catch (err) {
    console.error('[Auth] Verification failed:', err)
    const message = err instanceof Error ? err.message : String(err)
    // If it's a network error or 5xx, allow retry instead of signing out immediately
    const isNetworkError = err instanceof TypeError || message.includes('fetch')
    onError(
      isNetworkError
        ? 'Backend connection failed. The server might be starting up...'
        : message || 'Unable to verify admin privileges.',
      true,
    )
    return null
  }
}
