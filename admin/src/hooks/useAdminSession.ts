import type { Session } from '@supabase/supabase-js'
import { useCallback, useEffect, useRef, useState } from 'react'
import { enforceAdminSession } from '../lib/adminVerification'
import { readAndClearUrlAuthError } from '../lib/authUrlParams'
import {
  ADMIN_SESSION_START_KEY,
  CHECK_INTERVAL_MS,
  SESSION_LIMIT_MS,
  WARNING_THRESHOLD_MS,
} from '../lib/sessionConfig'
import { supabase } from '../lib/supabase'

export type AuthPhase = 'signedOut' | 'verifying' | 'authenticated'

export interface SessionWarning {
  remainingMs: number
}

export interface AdminSession {
  phase: AuthPhase
  session: Session | null
  authError: string | null
  authRetryVisible: boolean
  userEmail: string | null
  sessionWarning: SessionWarning | null
  login: (email: string, password: string) => Promise<void>
  loginWithGoogle: () => Promise<void>
  logout: () => Promise<void>
  retryVerification: () => void
  extendSession: () => void
}

/**
 * Owns the full admin auth lifecycle: Supabase session state, the
 * /api/admin/session/check verification (with its legacy-probe fallback for
 * older deployments), and the 12h client-side session-expiry timer with its
 * 5-minute warning. Ported from admin/app.js's init/performAdminVerification/
 * checkSessionExpiry — see that file's history for the original.
 */
export function useAdminSession(): AdminSession {
  const [phase, setPhase] = useState<AuthPhase>('signedOut')
  const [session, setSession] = useState<Session | null>(null)
  const [authError, setAuthErrorState] = useState<string | null>(null)
  const [authRetryVisible, setAuthRetryVisible] = useState(false)
  const [userEmail, setUserEmail] = useState<string | null>(null)
  const [sessionWarning, setSessionWarning] = useState<SessionWarning | null>(null)

  const isCheckingAdminRef = useRef(false)
  const sessionStartTimeRef = useRef<number | null>(null)
  const checkIntervalRef = useRef<number | null>(null)
  const sessionRef = useRef<Session | null>(null)

  const setAuthError = useCallback((message: string | null, showRetry = false) => {
    setAuthErrorState(message)
    setAuthRetryVisible(showRetry)
  }, [])

  const stopSessionTimer = useCallback(() => {
    if (checkIntervalRef.current !== null) {
      window.clearInterval(checkIntervalRef.current)
      checkIntervalRef.current = null
    }
    setSessionWarning(null)
  }, [])

  const checkSessionExpiry = useCallback(() => {
    if (!sessionRef.current || !sessionStartTimeRef.current) return

    const elapsed = Date.now() - sessionStartTimeRef.current
    const remaining = SESSION_LIMIT_MS - elapsed

    if (remaining <= 0) {
      alert('Session expired. Logging out now.')
      void supabase.auth.signOut()
    } else if (remaining <= WARNING_THRESHOLD_MS) {
      setSessionWarning({ remainingMs: remaining })
    } else {
      setSessionWarning(null)
    }
  }, [])

  const startSessionTimer = useCallback(() => {
    if (checkIntervalRef.current !== null) window.clearInterval(checkIntervalRef.current)
    checkIntervalRef.current = window.setInterval(checkSessionExpiry, CHECK_INTERVAL_MS)
  }, [checkSessionExpiry])

  const performAdminVerification = useCallback(async (activeSession: Session) => {
    if (isCheckingAdminRef.current) return

    isCheckingAdminRef.current = true
    setPhase('verifying')
    setAuthError(null)

    const isAdmin = await enforceAdminSession(
      activeSession.access_token,
      (email) => setUserEmail(email),
      (message, showRetry) => setAuthError(message, showRetry),
    )
    isCheckingAdminRef.current = false

    if (isAdmin === true) {
      const savedStart = sessionStorage.getItem(ADMIN_SESSION_START_KEY)
      const startTime = savedStart ? parseInt(savedStart, 10) : Date.now()
      sessionStartTimeRef.current = startTime
      if (!savedStart) sessionStorage.setItem(ADMIN_SESSION_START_KEY, String(startTime))
      startSessionTimer()
      setPhase('authenticated')
    } else {
      // false (denied) or null (transient) both land back on the login
      // screen; enforceAdminSession has already set the error/retry state.
      setPhase('signedOut')
    }
  }, [setAuthError, startSessionTimer])

  useEffect(() => {
    const urlError = readAndClearUrlAuthError()
    if (urlError) setAuthError(urlError)

    void supabase.auth.getSession().then(({ data }) => {
      sessionRef.current = data.session
      setSession(data.session)
    })

    const { data: subscription } = supabase.auth.onAuthStateChange((event, changedSession) => {
      console.log('[Auth] State change:', event, changedSession ? 'Session present' : 'No session')
      sessionRef.current = changedSession
      setSession(changedSession)

      if (event === 'SIGNED_IN' || event === 'INITIAL_SESSION' || event === 'USER_UPDATED') {
        if (changedSession && !isCheckingAdminRef.current) {
          void performAdminVerification(changedSession)
        }
      } else if (event === 'SIGNED_OUT') {
        sessionStartTimeRef.current = null
        sessionStorage.removeItem(ADMIN_SESSION_START_KEY)
        stopSessionTimer()
        setPhase('signedOut')
        setUserEmail(null)
      }
    })

    return () => subscription.subscription.unsubscribe()
    // Intentionally mount-only: performAdminVerification/stopSessionTimer are
    // stable across the session's lifetime via useCallback.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    setAuthError(null)
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) setAuthError(error.message)
  }, [setAuthError])

  const loginWithGoogle = useCallback(async () => {
    // Keep redirectTo stable across hosting setups (e.g. /admin/ vs /admin/index.html)
    // and ensure it ends with a trailing slash so Supabase allowlisting is predictable.
    let redirectPath = window.location.pathname
    redirectPath = redirectPath.replace(/index\.html$/, '')
    if (!redirectPath.endsWith('/')) {
      const lastSegment = redirectPath.split('/').pop() || ''
      if (!lastSegment.includes('.')) {
        redirectPath += '/'
      }
    }
    const redirectTo = window.location.origin + redirectPath
    console.log('[Auth] Initiating Google login with redirectTo:', redirectTo)

    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo,
        queryParams: { prompt: 'select_account' },
      },
    })

    if (error) {
      console.error('[Auth] signInWithOAuth error:', error)
      setAuthError(error.message)
    }
  }, [setAuthError])

  const logout = useCallback(async () => {
    await supabase.auth.signOut()
  }, [])

  const retryVerification = useCallback(() => {
    if (sessionRef.current) void performAdminVerification(sessionRef.current)
  }, [performAdminVerification])

  const extendSession = useCallback(() => {
    sessionStartTimeRef.current = Date.now()
    sessionStorage.setItem(ADMIN_SESSION_START_KEY, String(sessionStartTimeRef.current))
    setSessionWarning(null)
  }, [])

  return {
    phase,
    session,
    authError,
    authRetryVisible,
    userEmail,
    sessionWarning,
    login,
    loginWithGoogle,
    logout,
    retryVerification,
    extendSession,
  }
}
