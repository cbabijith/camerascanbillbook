'use server'

import { createClient } from '@/lib/supabase/server'
import { cookies } from 'next/headers'

import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { revalidatePath, revalidateTag } from 'next/cache'

export { getCurrentUserAndBranch }


export async function setActiveBranch(branchId: string) {
  const cookieStore = await cookies()
  cookieStore.set('active_branch_id', branchId)
  return { success: true }
}

export async function searchCustomers(query: string) {
  const { branchId } = await getCurrentUserAndBranch()
  if (!branchId) return []

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('customers')
    .select('*')
    .eq('branch_id', branchId)
    .or(`name.ilike.%${query}%,phone.ilike.%${query}%`)
    .limit(10)

  if (error) {
    console.error('Error searching customers:', error)
    return []
  }
  return data || []
}

export async function searchProducts(query: string) {
  const { branchId } = await getCurrentUserAndBranch()
  if (!branchId) return []

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('branch_id', branchId)
    .or(`name.ilike.%${query}%,sku.ilike.%${query}%,brand.ilike.%${query}%`)
    .limit(10)

  if (error) {
    console.error('Error searching products:', error)
    return []
  }
  return data || []
}

export interface BillItemInput {
  productId: string | 'new'
  name: string
  brand: string
  category: string
  sku: string
  sellingPrice: number
  mrp?: number | null
  qty: number
}

export async function createBill(data: {
  customerId: string | 'new' | null
  customerName: string
  customerPhone: string
  customerEmail?: string
  customerAddress?: string
  items: BillItemInput[]
  paymentStatus: 'paid' | 'unpaid'
}) {
  const { user, branchId } = await getCurrentUserAndBranch()
  if (!user || !branchId) {
    return { error: 'Unauthorized or no active branch selected.' }
  }

  const supabase = await createClient()

  // 1. Resolve Customer (Create inline if 'new' or not exists)
  let customerId = data.customerId
  if (!customerId || customerId === 'new') {
    // Check if customer with this phone already exists in this branch
    const { data: existingCustomer } = await supabase
      .from('customers')
      .select('id')
      .eq('branch_id', branchId)
      .eq('phone', data.customerPhone)
      .maybeSingle()

    if (existingCustomer) {
      customerId = existingCustomer.id
    } else {
      // Create new customer
      const { data: newCustomer, error: custError } = await supabase
        .from('customers')
        .insert({
          branch_id: branchId,
          name: data.customerName,
          phone: data.customerPhone,
          email: data.customerEmail || null,
          address: data.customerAddress || null,
          created_by: user.id,
          updated_by: user.id
        })
        .select()
        .single()

      if (custError) {
        return { error: `Failed to save customer: ${custError.message}` }
      }
      customerId = newCustomer.id
    }
  }

  // 2. Resolve Products (Create inline if 'new' or not exists) in parallel
  let resolvedItems: any[] = []
  try {
    resolvedItems = await Promise.all(
      data.items.map(async (item) => {
        let resolvedProductId = item.productId

        if (resolvedProductId === 'new') {
          // Check if product with this serial number already exists in this branch
          const { data: existingProduct } = await supabase
            .from('products')
            .select('id')
            .eq('branch_id', branchId)
            .eq('sku', item.sku)
            .maybeSingle()

          if (existingProduct) {
            resolvedProductId = existingProduct.id
          } else {
            // Create product inline
            const { data: newProduct, error: prodError } = await supabase
              .from('products')
              .insert({
                branch_id: branchId,
                name: item.name,
                brand: item.brand || null,
                category: item.category || null,
                sku: item.sku,
                selling_price: item.sellingPrice,
                mrp: item.mrp ?? null,
                gst_rate: 0,
                created_by: user.id,
                updated_by: user.id
              })
              .select()
              .single()

            if (prodError) {
              throw new Error(`Failed to save product ${item.name}: ${prodError.message}`)
            }
            resolvedProductId = newProduct.id
          }
        }

        return {
          ...item,
          resolvedProductId
        }
      })
    )
  } catch (err: any) {
    return { error: err.message }
  }

  const processedItems = []
  let totalSubTotal = 0
  let totalFinal = 0

  for (const item of resolvedItems) {
    const itemTotal = item.sellingPrice * item.qty

    totalSubTotal += itemTotal
    totalFinal += itemTotal

    processedItems.push({
      productId: item.resolvedProductId,
      name: item.name,
      brand: item.brand,
      category: item.category,
      sku: item.sku,
      sellingPrice: item.sellingPrice,
      mrp: item.mrp ?? null,
      qty: item.qty,
      basePrice: Math.round(itemTotal * 100) / 100,
      gstAmount: 0,
      total: Math.round(itemTotal * 100) / 100
    })
  }

  // 3. Generate Sequential Bill Number (with retry for concurrent collisions)
  const MAX_RETRIES = 3
  let bill: any = null
  let billError: any = null

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const { count, error: countError } = await supabase
      .from('bills')
      .select('id', { count: 'exact', head: true })
      .eq('branch_id', branchId)

    if (countError) {
      return { error: `Failed to generate bill number: ${countError.message}` }
    }

    const nextIndex = (count || 0) + 1 + attempt
    const paddedNumber = String(nextIndex).padStart(4, '0')
    const billNumber = `INV-${paddedNumber}`

    // 4. Save Bill
    const result = await supabase
      .from('bills')
      .insert({
        bill_number: billNumber,
        branch_id: branchId,
        user_id: user.id,
        customer_id: customerId,
        customer_name: data.customerName,
        customer_phone: data.customerPhone,
        items: processedItems,
        sub_total: Math.round(totalSubTotal * 100) / 100,
        gst_amount: 0,
        total: Math.round(totalFinal * 100) / 100,
        payment_status: data.paymentStatus,
        created_by: user.id,
        updated_by: user.id
      })
      .select()
      .single()

    bill = result.data
    billError = result.error

    if (!billError) break

    // Retry only on unique constraint violation (23505)
    if (billError.code !== '23505') break
  }

  if (billError) {
    return { error: `Failed to generate invoice: ${billError.message}` }
  }

  revalidatePath('/dashboard')
  revalidatePath('/dashboard/bills')
  revalidateTag('bills', 'max')
  revalidateTag('customers', 'max')
  revalidateTag('products', 'max')

  return { success: true, billId: bill.id }
}
