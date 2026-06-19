import { unstable_cache } from 'next/cache'
import { createServerClient } from '@supabase/ssr'

/**
 * Cached server-side data queries.
 *
 * IMPORTANT: We use a cookie-free Supabase client here because
 * `unstable_cache` forbids dynamic APIs like `cookies()` inside
 * its callback. Auth is already verified in the page component
 * before these functions are called, and queries are filtered by
 * branchId for data isolation.
 *
 * Cache is invalidated via `revalidateTag()` when mutations occur
 * (see server actions in /app/actions/).
 */

function createCacheClient() {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    {
      cookies: {
        getAll() {
          return []
        },
        setAll() {},
      },
    }
  )
}

export const getCachedBills = (branchId: string) =>
  unstable_cache(
    async () => {
      const supabase = createCacheClient()
      const { data, error } = await supabase
        .from('bills')
        .select('*, profiles:user_id(name)')
        .eq('branch_id', branchId)
        .order('created_at', { ascending: false })

      if (error) {
        console.error('Error fetching bills:', error)
        return []
      }
      return data || []
    },
    [`bills-${branchId}`],
    {
      tags: ['bills', `bills-${branchId}`],
      revalidate: 60,
    }
  )()

export const getCachedCustomers = (branchId: string) =>
  unstable_cache(
    async () => {
      const supabase = createCacheClient()
      const { data } = await supabase
        .from('customers')
        .select('*, creator:profiles!created_by(name)')
        .eq('branch_id', branchId)
        .order('name', { ascending: true })

      return data || []
    },
    [`customers-${branchId}`],
    {
      tags: ['customers', `customers-${branchId}`],
      revalidate: 60,
    }
  )()

export const getCachedProducts = (branchId: string) =>
  unstable_cache(
    async () => {
      const supabase = createCacheClient()
      const { data } = await supabase
        .from('products')
        .select('*, creator:profiles!created_by(name)')
        .eq('branch_id', branchId)
        .order('name', { ascending: true })

      return data || []
    },
    [`products-${branchId}`],
    {
      tags: ['products', `products-${branchId}`],
      revalidate: 60,
    }
  )()

export const getCachedBranches = () =>
  unstable_cache(
    async () => {
      const supabase = createCacheClient()
      const { data } = await supabase
        .from('branches')
        .select('*')
        .order('name', { ascending: true })

      return data || []
    },
    ['all-branches'],
    {
      tags: ['branches'],
      revalidate: 120,
    }
  )()

export const getCachedStaff = () =>
  unstable_cache(
    async () => {
      const supabase = createCacheClient()
      const { data } = await supabase
        .from('profiles')
        .select('*, branches(name)')
        .eq('role', 'staff')
        .order('name', { ascending: true })

      return data || []
    },
    ['all-staff'],
    {
      tags: ['staff'],
      revalidate: 120,
    }
  )()
