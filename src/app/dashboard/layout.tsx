import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import SidebarNav from './sidebar-nav'
import BranchSelector from './branch-selector'
import { Camera, LogOut, User as UserIcon } from 'lucide-react'
import { signOut } from '../actions/auth'
import { Toaster } from '@/components/ui/sonner'
import BottomNav from './bottom-nav'

export default async function DashboardLayout({
  children
}: {
  children: React.ReactNode
}) {
  const { user, branchId, role, activeBranch: cachedActiveBranch } = await getCurrentUserAndBranch()

  if (!user || !branchId) {
    const supabase = await createClient()
    await supabase.auth.signOut()
    redirect('/login')
  }

  const supabase = await createClient()

  const activeBranch = cachedActiveBranch
  let branches: { id: string; name: string; address?: string; phone?: string; gstin?: string }[] = []

  if (role === 'admin') {
    const { data: branchesRes } = await supabase
      .from('branches')
      .select('*')
      .order('name', { ascending: true })
    branches = branchesRes || []
  }

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-zinc-50 text-zinc-900">
      {/* Sidebar */}
      <aside className="hidden md:flex flex-col w-64 border-r border-zinc-200 bg-zinc-100/60 backdrop-blur-md">
        {/* Sidebar Header */}
        <div className="flex h-16 items-center px-6 border-b border-zinc-200 gap-2">
          <Camera className="h-6 w-6 text-indigo-600" />
          <span className="font-bold tracking-tight text-zinc-900">SimpleBilling</span>
        </div>

        {/* Sidebar Nav */}
        <div className="flex-1 px-4 py-6 overflow-y-auto">
          <SidebarNav role={role} />
        </div>

        {/* Sidebar Footer */}
        <div className="p-4 border-t border-zinc-200 bg-zinc-100/20">
          <div className="flex items-center gap-3 px-2 py-3 rounded-lg bg-zinc-200/40">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-zinc-300 text-zinc-600">
              <UserIcon className="h-4 w-4" />
            </div>
            <div className="flex-1 overflow-hidden">
              <p className="text-sm font-semibold truncate text-zinc-800">{user.name}</p>
              <p className="text-xs text-zinc-500 capitalize">{role}</p>
            </div>
          </div>
          <form action={signOut} className="mt-3">
            <button
              type="submit"
              className="flex w-full items-center gap-2 px-3 py-2 text-sm text-zinc-500 hover:text-rose-600 hover:bg-rose-500/10 rounded-md transition-colors"
            >
              <LogOut className="h-4 w-4" />
              Sign Out
            </button>
          </form>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col h-full overflow-hidden">
        {/* Top Header */}
        <header className="flex h-16 items-center justify-between px-4 md:px-6 border-b border-zinc-200 bg-white/80">
          <div className="flex items-center gap-4">
            {/* Mobile Title */}
            <div className="flex items-center gap-2 md:hidden">
              <Camera className="h-5 w-5 text-indigo-600" />
              <span className="font-bold text-sm tracking-tight text-zinc-900 hidden xs:inline">SimpleBilling</span>
            </div>

            {/* Active Branch Display / Selection */}
            {role === 'admin' ? (
              <div className="flex items-center gap-2">
                <span className="text-xs text-zinc-500 font-semibold uppercase tracking-wider hidden sm:inline">Active Branch:</span>
                <BranchSelector branches={branches} activeBranchId={branchId} />
              </div>
            ) : (
              <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-2">
                <span className="text-xs text-zinc-500 font-semibold uppercase tracking-wider">Branch:</span>
                <span className="text-sm font-medium text-zinc-805 bg-white px-2.5 py-0.5 rounded border border-zinc-205">
                  {activeBranch?.name || 'Loading branch...'}
                </span>
              </div>
            )}
          </div>

          {/* Right Header Controls */}
          <div className="flex items-center gap-3">
            <span className="text-xs text-zinc-500 hidden md:inline">
              Shop Location: <span className="text-zinc-650 font-medium">{activeBranch?.address || 'N/A'}</span>
            </span>
            <form action={signOut} className="md:hidden">
              <button
                type="submit"
                className="flex items-center justify-center h-8 w-8 text-zinc-500 hover:text-rose-600 hover:bg-rose-50 rounded-md transition-colors border border-zinc-200 bg-white"
                title="Sign Out"
              >
                <LogOut className="h-4 w-4" />
              </button>
            </form>
          </div>
        </header>

        {/* Main Content */}
        <main className="flex-1 overflow-y-auto p-4 md:p-6 bg-zinc-50/50 pb-20 md:pb-6">
          {children}
        </main>

        {/* Bottom Navigation on Mobile */}
        <BottomNav role={role} />
      </div>

      <Toaster theme="light" closeButton />
    </div>
  )
}
