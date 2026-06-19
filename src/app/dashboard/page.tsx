import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import dynamic from 'next/dynamic'

const BillingForm = dynamic(() => import('./billing-form'), {
  loading: () => (
    <div className="animate-pulse space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-1 space-y-6 order-2 lg:order-1">
          <div className="border border-zinc-200 bg-white shadow-sm rounded-lg p-6 h-64" />
          <div className="border border-zinc-200 bg-white shadow-sm rounded-lg p-6 h-48" />
        </div>
        <div className="lg:col-span-2 order-1 lg:order-2">
          <div className="border border-zinc-200 bg-white shadow-sm rounded-lg p-6 h-96" />
        </div>
      </div>
    </div>
  ),
})

export default async function DashboardPage() {
  const { user, branchId, role } = await getCurrentUserAndBranch()

  if (!user || !branchId) {
    redirect('/login')
  }

  // Admins go to analytics, staff go to create invoice
  if (role === 'admin') {
    redirect('/dashboard/analytics')
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Create Invoice</h1>
          <p className="text-sm text-zinc-500">Create new customer invoices and save new contacts/products inline.</p>
        </div>
      </div>
      <BillingForm />
    </div>
  )
}
