import { useEffect, useRef, useState } from 'react'
import { COUNTRIES } from '../data/countries'
import styles from './CountrySelect.module.css'

interface Props {
  value: string | null
  onChange: (code: string | null) => void
}

function labelFor(code: string | null): string {
  if (!code) return ''
  const country = COUNTRIES.find((c) => c.code === code)
  return country ? `${country.name} (${country.code})` : ''
}

export function CountrySelect({ value, onChange }: Props) {
  // null = not actively typing, so the field mirrors the selected country.
  // Non-null only while the dropdown is open and the user is filtering —
  // closing it (select or click-outside) drops back to null.
  const [typedQuery, setTypedQuery] = useState<string | null>(null)
  const [isOpen, setIsOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  const displayValue = isOpen && typedQuery !== null ? typedQuery : labelFor(value)

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false)
        setTypedQuery(null)
      }
    }
    document.addEventListener('click', handleClickOutside)
    return () => document.removeEventListener('click', handleClickOutside)
  }, [])

  // Filters on what was actually typed, not the derived display value — an
  // untouched selection (typedQuery still null) should show the full list
  // on focus, not just the one already-selected entry.
  const filtered = COUNTRIES.filter((c) =>
    `${c.name} (${c.code})`.toLowerCase().includes((typedQuery ?? '').toLowerCase()),
  )

  function selectCountry(code: string | null) {
    onChange(code)
    setTypedQuery(null)
    setIsOpen(false)
  }

  return (
    <div className={styles.dropdown} ref={containerRef}>
      <input
        type="text"
        placeholder="Search country..."
        autoComplete="off"
        value={displayValue}
        onFocus={() => setIsOpen(true)}
        onChange={(e) => {
          setTypedQuery(e.target.value)
          onChange(null)
        }}
      />
      <div className={`${styles.dropdownOptions} ${isOpen ? styles.active : ''}`}>
        <div className={styles.dropdownOption} onClick={() => selectCountry(null)}>
          No country
        </div>
        {filtered.map((c) => (
          <div
            key={c.code}
            className={`${styles.dropdownOption} ${value === c.code ? styles.selected : ''}`}
            onClick={() => selectCountry(c.code)}
          >
            {c.name} ({c.code})
          </div>
        ))}
      </div>
    </div>
  )
}
