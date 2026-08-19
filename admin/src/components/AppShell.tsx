import { useState } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import type { AdminSession } from '../hooks/useAdminSession'
import { ToastProvider } from '../hooks/useToast'
import { AnalyticsPage } from '../routes/AnalyticsPage'
import { IngestionPage } from '../routes/IngestionPage'
import { QueryExplorerPage } from '../routes/QueryExplorerPage'
import styles from './AppShell.module.css'
import { Header } from './Header'
import { SessionWarningModal } from './SessionWarningModal'
import { Sidebar } from './Sidebar'
import { Toast } from './Toast'

interface Props {
  auth: AdminSession
}

export function AppShell({ auth }: Props) {
  // Starts as an icon rail on narrow viewports instead of the full sidebar —
  // matches the legacy behavior in admin/app.js's setupEventListeners.
  const [collapsed, setCollapsed] = useState(() => window.matchMedia('(max-width: 900px)').matches)

  // Only rendered once auth.phase === 'authenticated', which requires a
  // verified session — null here would mean that state machine broke.
  const token = auth.session?.access_token
  if (!token) return null

  return (
    <ToastProvider>
      <div className={styles.container}>
        <Header sidebarCollapsed={collapsed} onToggleSidebar={() => setCollapsed((c) => !c)} onLogout={() => void auth.logout()} />

        <div className={styles.dashboardLayout}>
          <Sidebar collapsed={collapsed} userEmail={auth.userEmail} />

          <main className={styles.mainContent}>
            <Routes>
              <Route path="/ingest" element={<IngestionPage token={token} />} />
              <Route path="/query" element={<QueryExplorerPage token={token} />} />
              <Route path="/analytics" element={<AnalyticsPage token={token} />} />
              <Route path="*" element={<Navigate to="/ingest" replace />} />
            </Routes>
          </main>
        </div>
      </div>

      <Toast />
      <SessionWarningModal auth={auth} />
    </ToastProvider>
  )
}
