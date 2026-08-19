import { createContext, type ReactNode, useCallback, useContext, useRef, useState } from 'react'

interface ToastContextValue {
  message: string | null
  showToast: (message: string) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [message, setMessage] = useState<string | null>(null)
  const timeoutRef = useRef<number | null>(null)

  const showToast = useCallback((next: string) => {
    if (timeoutRef.current !== null) window.clearTimeout(timeoutRef.current)
    setMessage(next)
    timeoutRef.current = window.setTimeout(() => setMessage(null), 3000)
  }, [])

  return <ToastContext.Provider value={{ message, showToast }}>{children}</ToastContext.Provider>
}

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be used within a ToastProvider')
  return ctx
}
