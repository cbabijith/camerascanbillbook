import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft } from 'lucide-react'
import BillingForm from '@/app/dashboard/billing-form'

export default async function EditBillPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  // Run user authentication/profile fetch and the bill query in parallel
  const [userBranchInfo, billResult] = await Promise.all([
    getCurrentUserAndBranch(),
    supabase.from('bills').select('*, payment_collections(*)').eq('id', id).single()
  ])

  const { user, branchId } = userBranchInfo
  const { data: bill, error } = billResult

  if (!user || !branchId || error || !bill || bill.branch_id !== branchId) {
    redirect('/dashboard/bills')
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link
            href="/dashboard/bills"
            className="inline-flex items-center justify-center rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900 transition-colors"
          >
            <ArrowLeft className="h-4 w-4 mr-1.5" />
            Back
          </Link>
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Edit Invoice</h1>
            <p className="text-sm text-zinc-500">Editing {bill.bill_number} - {bill.customer_name}</p>
          </div>
        </div>
      </div>
      <BillingForm editBill={bill} />
    </div>
  )
}
