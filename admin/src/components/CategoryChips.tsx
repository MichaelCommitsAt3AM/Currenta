import { VALID_CATEGORIES } from '../data/categories'
import styles from './CategoryChips.module.css'

interface Props {
  selected: string[]
  onToggle: (category: string) => void
}

export function CategoryChips({ selected, onToggle }: Props) {
  return (
    <div className={styles.chipContainer}>
      {VALID_CATEGORIES.map((cat) => (
        <div
          key={cat}
          className={`${styles.chip} ${selected.includes(cat) ? styles.active : ''}`}
          onClick={() => onToggle(cat)}
        >
          {cat.charAt(0).toUpperCase() + cat.slice(1)}
        </div>
      ))}
    </div>
  )
}
