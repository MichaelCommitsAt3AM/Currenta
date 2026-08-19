import { ArcElement, Chart as ChartJS, Legend, Tooltip } from 'chart.js'
import { Pie } from 'react-chartjs-2'

ChartJS.register(ArcElement, Tooltip, Legend)

const STATUS_COLORS: Record<string, string> = {
  SUCCESS: '#10b981',
  FAILED: '#ef4444',
  SKIPPED: '#f59e0b',
  REQUESTED: '#3b82f6',
}

interface Props {
  data: { status: string; count: number }[]
}

export function HealthChart({ data }: Props) {
  return (
    <Pie
      data={{
        labels: data.map((d) => d.status),
        datasets: [
          {
            data: data.map((d) => d.count),
            backgroundColor: data.map((d) => STATUS_COLORS[d.status] ?? '#94a3b8'),
            borderWidth: 0,
          },
        ],
      }}
      options={{
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'right', labels: { color: '#94a3b8', padding: 20, font: { family: 'Inter' } } },
        },
      }}
    />
  )
}
