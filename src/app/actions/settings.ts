'use server'

import { createClient, createAdminClient } from '@/lib/supabase/server'
import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { revalidatePath, revalidateTag } from 'next/cache'

// --- PRODUCTS CRUD ---

export async function createProduct(formData: FormData) {
  const { user, branchId } = await getCurrentUserAndBranch()
  if (!user || !branchId) return { error: 'Unauthorized.' }

  const name = formData.get('name') as string
  const brand = formData.get('brand') as string
  const category = formData.get('category') as string
  const sku = formData.get('sku') as string
  const sellingPrice = parseFloat(formData.get('sellingPrice') as string)
  const mrp = formData.get('mrp') as string

  if (!name || !sku || isNaN(sellingPrice)) {
    return { error: 'Please enter a valid name, serial number, and selling price.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.from('products').insert({
    branch_id: branchId,
    name,
    brand: brand || null,
    category: category || null,
    sku,
    selling_price: sellingPrice,
    mrp: mrp ? parseFloat(mrp) : null,
    gst_rate: 0,
    created_by: user.id,
    updated_by: user.id
  })

  if (error) {
    if (error.code === '23505') {
      return { error: 'A product with this serial number already exists in this branch.' }
    }
    return { error: error.message }
  }

  revalidatePath('/dashboard/products')
  revalidateTag('products', 'max')
  return { success: true }
}

export async function updateProduct(id: string, formData: FormData) {
  const { user } = await getCurrentUserAndBranch()
  if (!user) return { error: 'Unauthorized.' }

  const name = formData.get('name') as string
  const brand = formData.get('brand') as string
  const category = formData.get('category') as string
  const sku = formData.get('sku') as string
  const sellingPrice = parseFloat(formData.get('sellingPrice') as string)
  const mrp = formData.get('mrp') as string

  if (!name || !sku || isNaN(sellingPrice)) {
    return { error: 'Please fill in all required fields correctly.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('products')
    .update({
      name,
      brand: brand || null,
      category: category || null,
      sku,
      selling_price: sellingPrice,
      mrp: mrp ? parseFloat(mrp) : null,
      gst_rate: 0,
      updated_by: user.id
    })
    .eq('id', id)

  if (error) {
    if (error.code === '23505') {
      return { error: 'A product with this serial number already exists in this branch.' }
    }
    return { error: error.message }
  }

  revalidatePath('/dashboard/products')
  revalidateTag('products', 'max')
  return { success: true }
}

export async function deleteProduct(id: string) {
  const { user } = await getCurrentUserAndBranch()
  if (!user) return { error: 'Unauthorized.' }

  const supabase = await createClient()
  const { error } = await supabase.from('products').delete().eq('id', id)

  if (error) return { error: error.message }

  revalidatePath('/dashboard/products')
  revalidateTag('products', 'max')
  return { success: true }
}

// --- CUSTOMERS CRUD ---

export async function createCustomer(formData: FormData) {
  const { user, branchId } = await getCurrentUserAndBranch()
  if (!user || !branchId) return { error: 'Unauthorized.' }

  const name = formData.get('name') as string
  const phone = formData.get('phone') as string
  const email = formData.get('email') as string
  const address = formData.get('address') as string

  if (!name || !phone) {
    return { error: 'Please enter customer name and phone number.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.from('customers').insert({
    branch_id: branchId,
    name,
    phone,
    email: email || null,
    address: address || null,
    created_by: user.id,
    updated_by: user.id
  })

  if (error) {
    if (error.code === '23505') {
      return { error: 'A customer with this phone number already exists in this branch.' }
    }
    return { error: error.message }
  }

  revalidatePath('/dashboard/customers')
  revalidateTag('customers', 'max')
  return { success: true }
}

export async function updateCustomer(id: string, formData: FormData) {
  const { user } = await getCurrentUserAndBranch()
  if (!user) return { error: 'Unauthorized.' }

  const name = formData.get('name') as string
  const phone = formData.get('phone') as string
  const email = formData.get('email') as string
  const address = formData.get('address') as string

  if (!name || !phone) {
    return { error: 'Please enter customer name and phone number.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('customers')
    .update({
      name,
      phone,
      email: email || null,
      address: address || null,
      updated_by: user.id
    })
    .eq('id', id)

  if (error) {
    if (error.code === '23505') {
      return { error: 'A customer with this phone number already exists in this branch.' }
    }
    return { error: error.message }
  }

  revalidatePath('/dashboard/customers')
  revalidateTag('customers', 'max')
  return { success: true }
}

export async function deleteCustomer(id: string) {
  const { user } = await getCurrentUserAndBranch()
  if (!user) return { error: 'Unauthorized.' }

  const supabase = await createClient()
  const { error } = await supabase.from('customers').delete().eq('id', id)

  if (error) return { error: error.message }

  revalidatePath('/dashboard/customers')
  revalidateTag('customers', 'max')
  return { success: true }
}

// --- BRANCHES CRUD (ADMIN ONLY) ---

export async function createBranch(formData: FormData) {
  const { user } = await getCurrentUserAndBranch()
  if (!user || user.role !== 'admin') return { error: 'Unauthorized.' }

  const name = formData.get('name') as string
  const address = formData.get('address') as string
  const phone = formData.get('phone') as string
  const gstin = formData.get('gstin') as string

  if (!name) return { error: 'Branch name is required.' }

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('branches')
    .insert({
      name,
      address: address || null,
      phone: phone || null,
      gstin: gstin || null
    })
    .select()
    .single()

  if (error) return { error: error.message }

  revalidatePath('/dashboard/settings')
  revalidateTag('branches', 'max')
  return { success: true, data }
}

export async function updateBranch(id: string, formData: FormData) {
  const { user } = await getCurrentUserAndBranch()
  if (!user || user.role !== 'admin') return { error: 'Unauthorized.' }

  const name = formData.get('name') as string
  const address = formData.get('address') as string
  const phone = formData.get('phone') as string
  const gstin = formData.get('gstin') as string

  if (!name) return { error: 'Branch name is required.' }

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('branches')
    .update({
      name,
      address: address || null,
      phone: phone || null,
      gstin: gstin || null
    })
    .eq('id', id)
    .select()
    .single()

  if (error) return { error: error.message }

  revalidatePath('/dashboard/settings')
  revalidateTag('branches', 'max')
  return { success: true, data }
}

export async function deleteBranch(id: string) {
  const { user } = await getCurrentUserAndBranch()
  if (!user || user.role !== 'admin') return { error: 'Unauthorized.' }

  const supabase = await createClient()
  const { error } = await supabase.from('branches').delete().eq('id', id)

  if (error) return { error: error.message }

  revalidatePath('/dashboard/settings')
  revalidateTag('branches', 'max')
  return { success: true }
}

// --- STAFF CRUD (ADMIN ONLY) ---

export async function createStaff(formData: FormData) {
  const { user } = await getCurrentUserAndBranch()
  if (!user || user.role !== 'admin') return { error: 'Unauthorized.' }

  const email = formData.get('email') as string
  const password = formData.get('password') as string
  const name = formData.get('name') as string
  const username = formData.get('username') as string
  const branchId = formData.get('branchId') as string

  if (!email || !password || !name || !username || !branchId) {
    return { error: 'All fields are required.' }
  }

  let adminClient
  try {
    adminClient = await createAdminClient()
  } catch {
    return { error: 'Server is missing SUPABASE_SERVICE_ROLE_KEY. Add it in Vercel environment variables to manage staff.' }
  }

  const { data, error } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      role: 'staff',
      username,
      name,
      branch_id: branchId
    }
  })

  if (error) return { error: error.message }

  const { data: newProfile } = await adminClient
    .from('profiles')
    .select('*, branches(name)')
    .eq('id', data.user.id)
    .single()

  revalidatePath('/dashboard/settings')
  revalidateTag('staff', 'max')
  return { success: true, data: newProfile }
}

export async function deleteStaff(id: string) {
  const { user } = await getCurrentUserAndBranch()
  if (!user || user.role !== 'admin') return { error: 'Unauthorized.' }

  let adminClient
  try {
    adminClient = await createAdminClient()
  } catch {
    return { error: 'Server is missing SUPABASE_SERVICE_ROLE_KEY. Add it in Vercel environment variables to manage staff.' }
  }

  // Delete from Auth (which cascades to profile)
  const { error } = await adminClient.auth.admin.deleteUser(id)

  if (error) return { error: error.message }

  revalidatePath('/dashboard/settings')
  revalidateTag('staff', 'max')
  return { success: true }
}
