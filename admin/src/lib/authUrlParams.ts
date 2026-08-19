import { config } from './config'

/**
 * Supabase OAuth redirects back with error details in the query string or
 * hash fragment (and sometimes a bare trailing '#' that carries no state).
 * Reads that once on mount, returns a message to show (or null), and always
 * cleans the URL so a refresh doesn't re-trigger it.
 */
export function readAndClearUrlAuthError(): string | null {
  const params = new URLSearchParams(window.location.search)
  const fragment = new URLSearchParams(window.location.hash.substring(1))

  const error = params.get('error') || fragment.get('error')
  const description = params.get('error_description') || fragment.get('error_description')
  const errorCode = params.get('error_code') || fragment.get('error_code')

  let message: string | null = null

  if (error) {
    console.error('[Auth] Login error detected in URL params:', { error, errorCode, description })

    message = `Login Error: ${description || error}`

    if ((description || '').includes('Unable to exchange external code')) {
      const supabaseCallback = `${config.supabaseUrl.replace(/\/$/, '')}/auth/v1/callback`
      message += `\n\nFix: In Google Cloud Console → OAuth client, add this as an Authorized redirect URI: ${supabaseCallback}. Then in Supabase → Auth → Providers → Google, ensure the Client ID/Secret match that OAuth client.`
    }

    if (errorCode) {
      message += `\n\n(error_code: ${errorCode})`
    }

    const cleanUrl = `${window.location.pathname}${window.location.search
      .replace(/[?&]error=[^&]*/, '')
      .replace(/[?&]error_description=[^&]*/, '')
      .replace(/[?&]error_code=[^&]*/, '')}`
    window.history.replaceState({}, document.title, cleanUrl)
  }

  if (window.location.hash === '#' || window.location.hash.includes('error=')) {
    const cleanUrl = `${window.location.pathname}${window.location.search}`
    window.history.replaceState({}, document.title, cleanUrl)
  }

  return message
}
