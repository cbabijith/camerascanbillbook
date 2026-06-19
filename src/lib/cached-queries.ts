import { createClient } from '@/lib/supabase/server'

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

async function createCacheClient() {
  return createClient()
}

export async function getCachedBills(branchId: string) {
  const supabase = await createCacheClient()
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
}

export async function getCachedCustomers(branchId: string) {
  const supabase = await createCacheClient()
  const { data } = await supabase
    .from('customers')
    .select('*, creator:profiles!created_by(name)')
    .eq('branch_id', branchId)
    .order('name', { ascending: true })

  return data || []
}

export async function getCachedProducts(branchId: string) {
  const supabase = await createCacheClient()
  const { data } = await supabase
    .from('products')
    .select('*, creator:profiles!created_by(name)')
    .eq('branch_id', branchId)
    .order('name', { ascending: true })

  return data || []
}

export async function getCachedBranches() {
  const supabase = await createCacheClient()
  const { data } = await supabase
    .from('branches')
    .select('*')
    .order('name', { ascending: true })

  return data || []
}

export async function getCachedStaff() {
  const supabase = await createCacheClient()
  const { data } = await supabase
    .from('profiles')
    .select('*, branches(name)')
    .eq('role', 'staff')
    .order('name', { ascending: true })

  return data || []
}

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
  try {
    const supabase = await createCacheClient()

    const { data: branches, error: branchesError } = await supabase
      .from('branches')
      .select('id, name')
      .order('name', { ascending: true })

    if (branchesError || !branches) {
    console.error('Analytics branches error:', branchesError?.message)
    return []
  }

  const results: BranchAnalytics[] = []

  for (const branch of branches) {
    const { data: bills } = await supabase
      .from('bills')
      .select('id, bill_number, customer_name, total, advance_amount, payment_status, user_id, created_at')
      .eq('branch_id', branch.id)
      .gte('created_at', startDate)
      .lt('created_at', endDate)

    const { data: allBranchBills } = await supabase
      .from('bills')
      .select('id, bill_number, customer_name, total, advance_amount, payment_status, created_at')
      .eq('branch_id', branch.id)

    const billIds = (bills || []).map(b => b.id)

    const { data: collections, error: collectionsError } = await supabase
      .from('payment_collections')
      .select('id, bill_id, amount, payment_method, payment_type, collected_at')
      .in('bill_id', billIds.length > 0 ? billIds : ['00000000-0000-0000-0000-000000000000'])

    if (collectionsError) {
      console.error('Collections query error:', collectionsError.message)
    }

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
    const userIds = [...new Set((bills || []).map(b => b.user_id).filter(Boolean))]
    const { data: profilesData } = await supabase
      .from('profiles')
      .select('id, name')
      .in('id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000'])
    const profileMap = new Map<string, string>()
    for (const p of profilesData || []) {
      profileMap.set(p.id, p.name)
    }
    for (const bill of bills || []) {
      const staffName = profileMap.get(bill.user_id) || 'Unknown'
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
  } catch (err) {
    console.error('Analytics data error:', err)
    return []
  }
}
