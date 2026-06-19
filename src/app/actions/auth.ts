'use server'

import { createClient, createAdminClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export async function checkIfSetupRequired() {
  const supabase = await createClient()
  const { count, error } = await supabase
    .from('profiles')
    .select('*', { count: 'exact', head: true })
  
  if (error) {
    console.error('Error checking setup status:', error)
    return false
  }

  return count === 0
}

export async function setupAdmin(formData: FormData) {
  const email = formData.get('email') as string
  const password = formData.get('password') as string
  const name = formData.get('name') as string
  const username = formData.get('username') as string
  
  const branchName = formData.get('branchName') as string
  const branchAddress = formData.get('branchAddress') as string
  const branchPhone = formData.get('branchPhone') as string
  const branchGstin = formData.get('branchGstin') as string

  if (!email || !password || !name || !username || !branchName) {
    return { error: 'Please fill in all required fields.' }
  }

  const supabase = await createClient()

  // 1. Create the first branch
  const { data: branch, error: branchError } = await supabase
    .from('branches')
    .insert({
      name: branchName,
      address: branchAddress || null,
      phone: branchPhone || null,
      gstin: branchGstin || null
    })
    .select()
    .single()

  if (branchError) {
    return { error: `Failed to create branch: ${branchError.message}` }
  }

  // 2. Use admin client to create user and bypass email confirmation
  const adminClient = await createAdminClient()
  const { data: user, error: userError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      role: 'admin',
      username,
      name,
      branch_id: branch.id
    }
  })

  if (userError) {
    // Clean up branch if user creation fails
    await supabase.from('branches').delete().eq('id', branch.id)
    return { error: `Failed to create admin account: ${userError.message}` }
  }

  redirect('/login')
}

export async function signIn(formData: FormData) {
  const email = formData.get('email') as string
  const password = formData.get('password') as string

  if (!email || !password) {
    return { error: 'Please enter both email and password.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.auth.signInWithPassword({
    email,
    password
  })

  if (error) {
    return { error: error.message }
  }

  redirect('/dashboard')
}

export async function signOut() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/login')
}
