import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { getCachedCustomers } from '@/lib/cached-queries'
import dynamic from 'next/dynamic'

const CustomersList = dynamic(() => import('./customers-list'))

export default async function CustomersPage() {
  const { user, branchId } = await getCurrentUserAndBranch()

  if (!user || !branchId) {
    redirect('/login')
  }

  const customers = await getCachedCustomers(branchId)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Customer Directory</h1>
        <p className="text-sm text-zinc-500">View and manage saved client contact details for this branch.</p>
      </div>
      <CustomersList initialCustomers={customers || []} />
    </div>
  )
}

