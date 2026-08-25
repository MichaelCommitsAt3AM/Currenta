import { useToast } from '../hooks/useToast'
import { CheckIcon } from './icons'
import styles from './Toast.module.css'

export function Toast() {
  const { message } = useToast()

  return (
    <div className={`${styles.toast} ${message ? '' : styles.hidden}`}>
      <CheckIcon />
      <span>{message}</span>
    </div>
  )
}
