import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { getCachedBills } from '@/lib/cached-queries'
import dynamic from 'next/dynamic'

const BillsList = dynamic(() => import('./bills-list'))

export default async function BillsPage() {
  const { user, branchId, activeBranch } = await getCurrentUserAndBranch()

  if (!user || !branchId) {
    redirect('/login')
  }

  const bills = await getCachedBills(branchId)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Invoice History</h1>
        <p className="text-sm text-zinc-500">View past invoices, print receipts, and share them on WhatsApp.</p>
      </div>
      <BillsList initialBills={bills || []} activeBranch={activeBranch} userRole={user?.role} />
    </div>
  )
}

