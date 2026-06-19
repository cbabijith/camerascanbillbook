import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const { user, branchId, role } = await getCurrentUserAndBranch()

  if (!user || !branchId) {
    redirect('/login')
  }

  if (role === 'admin') {
    redirect('/dashboard/analytics')
  }

  redirect('/dashboard/create')
}
