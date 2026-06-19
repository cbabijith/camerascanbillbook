import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { getCachedBills } from '@/lib/cached-queries'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import { PlusCircle } from 'lucide-react'

const BillsList = dynamic(() => import('./bills-list'))

export default async function BillsPage() {
  const { user, branchId, activeBranch, role } = await getCurrentUserAndBranch()

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

      {role === 'admin' && (
        <Link
          href="/dashboard"
          className="fixed bottom-20 right-6 md:bottom-6 z-50 flex items-center gap-2 rounded-full bg-indigo-600 px-5 py-3 text-sm font-semibold text-white shadow-lg shadow-indigo-500/30 hover:bg-indigo-500 transition-colors"
        >
          <PlusCircle className="h-5 w-5" />
          New Invoice
        </Link>
      )}
    </div>
  )
}

