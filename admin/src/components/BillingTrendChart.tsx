import {
  CategoryScale,
  Chart as ChartJS,
  Filler,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
} from 'chart.js'
import { Line } from 'react-chartjs-2'

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Filler, Tooltip)

interface Props {
  data: { date: string; cost: number }[]
  currency: string
}

export function BillingTrendChart({ data, currency }: Props) {
  return (
    <Line
      data={{
        labels: data.map((d) => d.date),
        datasets: [
          {
            data: data.map((d) => d.cost),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.15)',
            fill: true,
            tension: 0.3,
            pointRadius: 2,
          },
        ],
      }}
      options={{
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `${currency} ${(ctx.raw as number).toFixed(2)}`,
            },
          },
        },
        scales: {
          x: { ticks: { color: '#94a3b8' }, grid: { display: false } },
          y: {
            ticks: {
              color: '#94a3b8',
              callback: (value) => `${currency} ${value}`,
            },
            grid: { color: 'rgba(148, 163, 184, 0.1)' },
          },
        },
      }}
    />
  )
}
