import { ArcElement, Chart as ChartJS, Legend, Tooltip } from 'chart.js'
import { Doughnut } from 'react-chartjs-2'

ChartJS.register(ArcElement, Tooltip, Legend)

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4', '#f97316', '#6366f1']

interface Props {
  data: { category: string; count: number }[]
}

export function CategoryChart({ data }: Props) {
  return (
    <Doughnut
      data={{
        labels: data.map((d) => d.category),
        datasets: [
          {
            data: data.map((d) => d.count),
            backgroundColor: COLORS,
            borderWidth: 0,
            hoverOffset: 10,
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
