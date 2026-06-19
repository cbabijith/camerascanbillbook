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
        .select('*, profiles:user_id(name), payment_collections(*, profiles:collected_by(name))')
        .eq('branch_id', branchId)
        .order('created_at', { ascending: false })
        .order('collected_at', { ascending: true, referencedTable: 'payment_collections' })

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

export interface BranchAnalytics {
  branchId: string
  branchName: string
  totalInvoices: number
  totalSales: number
  totalReceived: number
  totalDue: number
  avgBillValue: number
  paymentMethodBreakdown: { method: string; count: number; amount: number }[]
  overdueDues: { billNumber: string; customerName: string; amount: number; age: number; branchName: string }[]
  staffRanking: {
    name: string
    billCount: number
    totalSales: number
    collectedAmount: number
  }[]
}

export async function getAnalyticsData(startDate: string, endDate: string): Promise<BranchAnalytics[]> {
  const supabase = createCacheClient()

  const { data: branches } = await supabase
    .from('branches')
    .select('id, name')
    .order('name', { ascending: true })

  if (!branches) return []

  const results: BranchAnalytics[] = []

  for (const branch of branches) {
    const { data: bills } = await supabase
      .from('bills')
      .select('id, bill_number, customer_name, total, advance_amount, payment_status, user_id, created_at, profiles:user_id(name)')
      .eq('branch_id', branch.id)
      .gte('created_at', startDate)
      .lt('created_at', endDate)

    const { data: allBranchBills } = await supabase
      .from('bills')
      .select('id, bill_number, customer_name, total, advance_amount, payment_status, created_at')
      .eq('branch_id', branch.id)

    const billIds = (bills || []).map(b => b.id)

    const { data: collections } = await supabase
      .from('payment_collections')
      .select('id, bill_id, amount, payment_method, payment_type, collected_at, profiles:collected_by(name)')
      .in('bill_id', billIds.length > 0 ? billIds : ['00000000-0000-0000-0000-000000000000'])

    const totalInvoices = bills?.length || 0
    const totalSales = (bills || []).reduce((sum, b) => sum + Number(b.total), 0)
    const totalReceived = (collections || []).reduce((sum, pc) => sum + Number(pc.amount), 0)
    const avgBillValue = totalInvoices > 0 ? totalSales / totalInvoices : 0

    const methodMap = new Map<string, { count: number; amount: number }>()
    for (const pc of collections || []) {
      const method = pc.payment_method || 'cash'
      const existing = methodMap.get(method) || { count: 0, amount: 0 }
      existing.count += 1
      existing.amount += Number(pc.amount)
      methodMap.set(method, existing)
    }
    const paymentMethodBreakdown = Array.from(methodMap.entries())
      .map(([method, val]) => ({ method, ...val }))
      .sort((a, b) => b.amount - a.amount)

    const overdueDues = (allBranchBills || [])
      .filter(b => b.payment_status !== 'paid')
      .map(b => {
        const due = Math.max(0, Number(b.total) - Number(b.advance_amount || 0))
        const age = Math.floor((Date.now() - new Date(b.created_at).getTime()) / (1000 * 60 * 60 * 24))
        return { billNumber: b.bill_number, customerName: b.customer_name, amount: due, age, branchName: branch.name }
      })
      .filter(d => d.amount > 0)
      .sort((a, b) => b.age - a.age)

    const totalDue = overdueDues.reduce((sum, d) => sum + d.amount, 0)

    const staffMap = new Map<string, { name: string; billCount: number; totalSales: number; collectedAmount: number }>()
    for (const bill of bills || []) {
      const profileData = bill.profiles as unknown as { name: string } | { name: string }[] | null
      const staffName = (Array.isArray(profileData) ? profileData[0]?.name : profileData?.name) || 'Unknown'
      const existing = staffMap.get(bill.user_id) || { name: staffName, billCount: 0, totalSales: 0, collectedAmount: 0 }
      existing.billCount += 1
      existing.totalSales += Number(bill.total)
      staffMap.set(bill.user_id, existing)
    }

    const staffBillIds = new Map<string, string[]>()
    for (const bill of bills || []) {
      const ids = staffBillIds.get(bill.user_id) || []
      ids.push(bill.id)
      staffBillIds.set(bill.user_id, ids)
    }

    for (const pc of collections || []) {
      for (const [userId, ids] of staffBillIds) {
        if (ids.includes(pc.bill_id)) {
          const existing = staffMap.get(userId)
          if (existing) existing.collectedAmount += Number(pc.amount)
        }
      }
    }

    const staffRanking = Array.from(staffMap.values())
      .sort((a, b) => b.billCount - a.billCount || b.totalSales - a.totalSales)

    results.push({
      branchId: branch.id,
      branchName: branch.name,
      totalInvoices,
      totalSales,
      totalReceived,
      totalDue,
      avgBillValue,
      paymentMethodBreakdown,
      overdueDues,
      staffRanking,
    })
  }

  return results
}
