'use client'

import { useState, useTransition } from 'react'
import { setupAdmin } from '../actions/auth'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Camera, Loader2, User, Building, Eye, EyeOff } from 'lucide-react'

export default function SetupForm() {
  const [error, setError] = useState<string | null>(null)
  const [isPending, startTransition] = useTransition()
  const [step, setStep] = useState(1) // Step 1: Admin, Step 2: Branch
  const [showPassword, setShowPassword] = useState(false)

  const [adminData, setAdminData] = useState({
    name: '',
    username: '',
    email: '',
    password: ''
  })

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (step === 1) {
      const formData = new FormData(e.currentTarget)
      setAdminData({
        name: formData.get('name') as string,
        username: formData.get('username') as string,
        email: formData.get('email') as string,
        password: formData.get('password') as string
      })
      setStep(2)
      return
    }

    setError(null)

    // Build FormData and manually append adminData since those inputs are hidden with state values
    const formData = new FormData(e.currentTarget)
    formData.set('name', adminData.name)
    formData.set('username', adminData.username)
    formData.set('email', adminData.email)
    formData.set('password', adminData.password)

    startTransition(async () => {
      try {
        const res = await setupAdmin(formData)
        if (res && res.error) {
          setError(res.error)
        }
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : 'An unexpected error occurred.')
      }
    })
  }

  return (
    <Card className="relative z-10 w-full max-w-xl border-zinc-200 bg-white/95 shadow-2xl backdrop-blur-md">
      <CardHeader className="space-y-2 text-center">
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-indigo-500/10 text-indigo-600">
          <Camera className="h-6 w-6" />
        </div>
        <CardTitle className="text-2xl font-bold tracking-tight text-zinc-900">Initial System Setup</CardTitle>
        <CardDescription className="text-zinc-500">
          Configure your camera shop billing admin account and your first branch.
        </CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit}>
        <CardContent className="space-y-6">
          {error && (
            <div className="rounded-md bg-rose-500/10 p-3 text-sm text-rose-600 border border-rose-500/20">
              {error}
            </div>
          )}

          {step === 1 ? (
            <div className="space-y-4">
              <div className="flex items-center gap-2 border-b border-zinc-205 pb-2 mb-2">
                <User className="h-5 w-5 text-indigo-600" />
                <h3 className="font-semibold text-zinc-800">1. Admin Account Details</h3>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="name" className="text-zinc-700">Full Name</Label>
                  <Input
                    id="name"
                    name="name"
                    placeholder="John Doe"
                    defaultValue={adminData.name}
                    required
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="username" className="text-zinc-700">Username</Label>
                  <Input
                    id="username"
                    name="username"
                    placeholder="admin"
                    defaultValue={adminData.username}
                    required
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="email" className="text-zinc-700">Email Address</Label>
                <Input
                  id="email"
                  name="email"
                  type="email"
                  placeholder="admin@example.com"
                  defaultValue={adminData.email}
                  required
                  className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password" className="text-zinc-700">Password</Label>
                <div className="relative">
                  <Input
                    id="password"
                    name="password"
                    type={showPassword ? "text" : "password"}
                    placeholder="•••••••• (Min 6 characters)"
                    defaultValue={adminData.password}
                    required
                    minLength={6}
                    className="pr-10 border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute inset-y-0 right-0 flex items-center pr-3 text-zinc-400 hover:text-zinc-600 transition-colors"
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="flex items-center gap-2 border-b border-zinc-205 pb-2 mb-2">
                <Building className="h-5 w-5 text-indigo-600" />
                <h3 className="font-semibold text-zinc-800">2. Primary Branch Details</h3>
              </div>
              {/* Keep fields from step 1 hidden so they submit */}
              <input type="hidden" name="name" value={adminData.name} />
              <input type="hidden" name="username" value={adminData.username} />
              <input type="hidden" name="email" value={adminData.email} />
              <input type="hidden" name="password" value={adminData.password} />

              <div className="space-y-2">
                <Label htmlFor="branchName" className="text-zinc-700">Branch / Shop Name</Label>
                <Input
                  id="branchName"
                  name="branchName"
                  placeholder="Main Branch"
                  required
                  className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="branchAddress" className="text-zinc-700">Branch Address</Label>
                <Input
                  id="branchAddress"
                  name="branchAddress"
                  placeholder="123 Shop Lane, Camera Town"
                  className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="branchPhone" className="text-zinc-700">Branch Contact Phone</Label>
                  <Input
                    id="branchPhone"
                    name="branchPhone"
                    placeholder="+91 98765 43210"
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="branchGstin" className="text-zinc-700">Branch GSTIN (Optional)</Label>
                  <Input
                    id="branchGstin"
                    name="branchGstin"
                    placeholder="22AAAAA0000A1Z5"
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
              </div>
            </div>
          )}
        </CardContent>
        <CardFooter className="flex gap-3">
          {step === 2 && (
            <Button
              type="button"
              variant="outline"
              onClick={() => setStep(1)}
              className="w-1/3 border-zinc-200 text-zinc-700 hover:bg-zinc-100"
            >
              Back
            </Button>
          )}
          <Button
            type="submit"
            disabled={isPending}
            className={`bg-indigo-600 text-white hover:bg-indigo-500 focus:ring-indigo-500 ${step === 2 ? 'w-2/3' : 'w-full'}`}
          >
            {isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Setting up...
              </>
            ) : step === 1 ? (
              'Next: Branch Setup'
            ) : (
              'Complete Setup'
            )}
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}
