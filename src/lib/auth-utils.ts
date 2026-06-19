import { cache } from 'react'
import { createClient } from '@/lib/supabase/server'
import { cookies } from 'next/headers'

export const getCurrentUserAndBranch = cache(async () => {
  const supabase = await createClient()
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    return { user: null, branchId: null, role: null, name: null, activeBranch: null }
  }

  // Get user profile
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('*, branches(*)')
    .eq('id', user.id)
    .single()

  if (profileError || !profile) {
    return { user: null, branchId: null, role: null, name: null, activeBranch: null }
  }

  let activeBranchId = profile.branch_id
  let activeBranch = profile.branches

  // If admin, check if active branch cookie is set
  if (profile.role === 'admin') {
    const cookieStore = await cookies()
    const activeBranchCookie = cookieStore.get('active_branch_id')?.value
    if (activeBranchCookie) {
      if (activeBranchCookie === profile.branch_id) {
        activeBranchId = profile.branch_id
        activeBranch = profile.branches
      } else {
        const { data: fetchedBranch } = await supabase
          .from('branches')
          .select('*')
          .eq('id', activeBranchCookie)
          .single()
        if (fetchedBranch) {
          activeBranchId = activeBranchCookie
          activeBranch = fetchedBranch
        }
      }
    } else {
      // Default to first branch if no cookie is set
      const { data: firstBranch } = await supabase
        .from('branches')
        .select('*')
        .limit(1)
        .single()
      if (firstBranch) {
        activeBranchId = firstBranch.id
        activeBranch = firstBranch
      }
    }
  }

  return {
    user: profile,
    branchId: activeBranchId,
    role: profile.role,
    name: profile.name,
    activeBranch
  }
})
