import type { AdminSession } from '../hooks/useAdminSession'
import { AlertTriangleIcon } from './icons'
import styles from './SessionWarningModal.module.css'

interface Props {
  auth: AdminSession
}

function formatCountdown(remainingMs: number): string {
  const minutes = Math.floor(remainingMs / 60000)
  const seconds = Math.floor((remainingMs % 60000) / 1000)
  return `${minutes}:${seconds.toString().padStart(2, '0')}`
}

export function SessionWarningModal({ auth }: Props) {
  if (!auth.sessionWarning) return null

  return (
    <div className="overlay">
      <div className={`glass-card ${styles.sessionCard}`}>
        <div className={styles.warningIcon}>
          <AlertTriangleIcon />
        </div>
        <h2>Session Expiring</h2>
        <p>
          Your session will expire in{' '}
          <span className={styles.countdown}>{formatCountdown(auth.sessionWarning.remainingMs)}</span>. Would
          you like to stay logged in?
        </p>
        <div className={styles.modalActions}>
          <button className="btn primary" onClick={auth.extendSession}>
            Continue Session
          </button>
          <button className="btn outline" onClick={() => void auth.logout()}>
            Logout Now
          </button>
        </div>
      </div>
    </div>
  )
}
