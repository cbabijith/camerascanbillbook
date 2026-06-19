import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { getCachedBranches, getCachedStaff } from '@/lib/cached-queries'
import dynamic from 'next/dynamic'

const SettingsPanel = dynamic(() => import('./settings-panel'))

export default async function SettingsPage() {
  const { user, role } = await getCurrentUserAndBranch()

  // Lock settings page to admin only
  if (!user || role !== 'admin') {
    redirect('/dashboard')
  }

  // Fetch branches and staff profiles concurrently (cached)
  const [branches, staff] = await Promise.all([
    getCachedBranches(),
    getCachedStaff()
  ])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-zinc-900">System Settings</h1>
        <p className="text-sm text-zinc-500">Configure branches and manage staff accounts.</p>
      </div>
      <SettingsPanel initialBranches={branches || []} initialStaff={staff || []} />
    </div>
  )
}

