import { NavLink } from 'react-router-dom'
import styles from './Sidebar.module.css'

const NAV_ITEMS = [
  { to: '/ingest', icon: '📥', label: 'Manual Ingestion' },
  { to: '/query', icon: '🔍', label: 'Database Explorer' },
  { to: '/analytics', icon: '📊', label: 'Analytics' },
  { to: '/trending', icon: '🔥', label: 'Trending' },
  { to: '/logs', icon: '📜', label: 'Backend Logs' },
]

interface Props {
  collapsed: boolean
  userEmail: string | null
}

export function Sidebar({ collapsed, userEmail }: Props) {
  return (
    <nav className={`${styles.sidebar} ${collapsed ? styles.collapsed : ''}`}>
      <ul className={styles.navLinks}>
        {NAV_ITEMS.map((item) => (
          <li key={item.to}>
            <NavLink
              to={item.to}
              className={({ isActive }) => `${styles.navItem} ${isActive ? styles.active : ''}`}
            >
              <span className={styles.navIcon}>{item.icon}</span>
              <span className={styles.navText}>{item.label}</span>
            </NavLink>
          </li>
        ))}
      </ul>
      <div className={styles.sidebarFooter}>
        <div className={styles.email}>{userEmail ?? ''}</div>
      </div>
    </nav>
  )
}
