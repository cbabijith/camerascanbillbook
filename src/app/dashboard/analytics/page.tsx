import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { getAnalyticsData } from '@/lib/cached-queries'
import AnalyticsView from './analytics-view'

export default async function AnalyticsPage() {
  const { user, role } = await getCurrentUserAndBranch()

  if (!user) {
    redirect('/login')
  }

  if (role !== 'admin') {
    redirect('/dashboard')
  }

  const now = new Date()
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  const endOfTomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).toISOString()

  const initialData = await getAnalyticsData(startOfMonth, endOfTomorrow)

  return <AnalyticsView initialData={initialData} />
}
