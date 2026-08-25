import { NavLink } from 'react-router-dom'
import { BarChartIcon, FileTextIcon, InboxIcon, SearchIcon, TrendingUpIcon } from './icons'
import styles from './Sidebar.module.css'

const NAV_ITEMS = [
  { to: '/ingest', icon: InboxIcon, label: 'Manual Ingestion' },
  { to: '/query', icon: SearchIcon, label: 'Database Explorer' },
  { to: '/analytics', icon: BarChartIcon, label: 'Analytics' },
  { to: '/trending', icon: TrendingUpIcon, label: 'Trending' },
  { to: '/logs', icon: FileTextIcon, label: 'Backend Logs' },
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
              <span className={styles.navIcon}>
                <item.icon />
              </span>
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
