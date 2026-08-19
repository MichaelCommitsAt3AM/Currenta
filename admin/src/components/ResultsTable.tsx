import { flexRender } from '@tanstack/react-table'
import {
  getCoreRowModel,
  getSortedRowModel,
  legacyCreateColumnHelper as createColumnHelper,
  useLegacyTable as useReactTable,
} from '@tanstack/react-table/legacy'
import { useMemo, useState } from 'react'
import styles from './ResultsTable.module.css'

type Row = Record<string, unknown>
type SortingState = { id: string; desc: boolean }[]

interface Props {
  columns: string[]
  data: Row[]
  selectedRow: Row | null
  onRowClick: (row: Row) => void
}

function Cell({ value }: { value: unknown }) {
  if (value === null) return <i style={{ color: 'hsla(0,0%,100%,0.2)' }}>null</i>
  const text = typeof value === 'object' ? JSON.stringify(value) : String(value)
  return <span title={text}>{text}</span>
}

const columnHelper = createColumnHelper<Row>()

export function ResultsTable({ columns, data, selectedRow, onRowClick }: Props) {
  const [sorting, setSorting] = useState<SortingState>([])

  const columnDefs = useMemo(
    () =>
      columns.map((col) =>
        columnHelper.accessor((row) => row[col], {
          id: col,
          header: col,
          cell: (info) => <Cell value={info.getValue()} />,
        }),
      ),
    [columns],
  )

  const table = useReactTable({
    data,
    columns: columnDefs,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  })

  if (data.length === 0) {
    return (
      <div className="table-wrapper">
        <table>
          <tbody>
            <tr>
              <td colSpan={columns.length || 1} style={{ textAlign: 'center', padding: '2rem' }}>
                No results found.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    )
  }

  return (
    <div className="table-wrapper">
      <table>
        <thead>
          {table.getHeaderGroups().map((headerGroup) => (
            <tr key={headerGroup.id}>
              {headerGroup.headers.map((header) => (
                <th key={header.id} className={styles.sortableHeader} onClick={header.column.getToggleSortingHandler()}>
                  {flexRender(header.column.columnDef.header, header.getContext())}
                  {{ asc: ' ▲', desc: ' ▼' }[header.column.getIsSorted() as string] ?? ''}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row) => (
            <tr
              key={row.id}
              className={row.original === selectedRow ? styles.selected : ''}
              onClick={() => onRowClick(row.original)}
            >
              {row.getVisibleCells().map((cell) => (
                <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
