import styles from './Header.module.css'

interface Props {
  sidebarCollapsed: boolean
  onToggleSidebar: () => void
  onLogout: () => void
}

export function Header({ sidebarCollapsed, onToggleSidebar, onLogout }: Props) {
  return (
    <header className={styles.header}>
      <div className={styles.headerLeft}>
        <button
          className={styles.sidebarToggleBtn}
          aria-label="Toggle sidebar"
          aria-pressed={sidebarCollapsed}
          onClick={onToggleSidebar}
        >
          <span className={styles.toggleIcon}>
            <span className={styles.bar} />
            <span className={styles.bar} />
            <span className={styles.bar} />
          </span>
        </button>
        <h1 className="logo">
          Currenta<span>.admin</span>
        </h1>
      </div>
      <button className="btn outline" onClick={onLogout}>
        Logout
      </button>
    </header>
  )
}
