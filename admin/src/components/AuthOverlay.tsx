import { type FormEvent, useRef } from 'react'
import type { AdminSession } from '../hooks/useAdminSession'
import styles from './AuthOverlay.module.css'

interface Props {
  auth: AdminSession
}

export function AuthOverlay({ auth }: Props) {
  const emailRef = useRef<HTMLInputElement>(null)
  const passwordRef = useRef<HTMLInputElement>(null)

  const verifying = auth.phase === 'verifying'

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    const email = emailRef.current?.value ?? ''
    const password = passwordRef.current?.value ?? ''
    void auth.login(email, password)
  }

  return (
    <div className="overlay active">
      <div className={`glass-card ${styles.authCard}`}>
        <h1 className="logo">
          Currenta<span>.admin</span>
        </h1>
        <p>Enter your credentials to manage niche news.</p>

        {!verifying && (
          <>
            <form onSubmit={handleSubmit}>
              <div className={styles.inputGroup}>
                <label htmlFor="email">Email</label>
                <input ref={emailRef} type="email" id="email" required placeholder="admin@currenta.tech" />
              </div>
              <div className={styles.inputGroup}>
                <label htmlFor="password">Password</label>
                <input ref={passwordRef} type="password" id="password" required placeholder="••••••••" />
              </div>
              <button type="submit" className="btn primary">
                Login
              </button>
            </form>

            <div className={styles.divider}>
              <span>OR</span>
            </div>

            <button className="btn google" onClick={() => void auth.loginWithGoogle()}>
              <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" alt="Google" />
              Sign in with Google
            </button>
          </>
        )}

        {auth.authError && <p className="error">{auth.authError}</p>}

        {verifying && (
          <div className={styles.authLoading}>
            <div className="loader-large" />
            <p>Verifying admin access...</p>
          </div>
        )}

        {auth.authRetryVisible && (
          <button className={`btn outline ${styles.retryBtn}`} onClick={auth.retryVerification}>
            Retry Verification
          </button>
        )}
      </div>
    </div>
  )
}
