import { useToast } from '../hooks/useToast'
import styles from './Toast.module.css'

export function Toast() {
  const { message } = useToast()

  return (
    <div className={`${styles.toast} ${message ? '' : styles.hidden}`}>
      <span>✓</span>
      <span>{message}</span>
    </div>
  )
}
