'use client'

import { useState, useTransition } from 'react'
import { signIn } from '../actions/auth'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Camera, Loader2, Eye, EyeOff } from 'lucide-react'

export default function LoginForm() {
  const [error, setError] = useState<string | null>(null)
  const [isPending, startTransition] = useTransition()
  const [showPassword, setShowPassword] = useState(false)

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError(null)

    const formData = new FormData(e.currentTarget)
    startTransition(async () => {
      try {
        const res = await signIn(formData)
        if (res && res.error) {
          setError(res.error)
        }
      } catch (err: unknown) {
        if (err instanceof Error && err.message.includes('NEXT_REDIRECT')) {
          return
        }
        setError(err instanceof Error ? err.message : 'An unexpected error occurred.')
      }
    })
  }

  return (
    <Card className="relative z-10 w-full max-w-md border-zinc-200 bg-white/95 shadow-2xl backdrop-blur-md">
      <CardHeader className="space-y-2 text-center">
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-indigo-500/10 text-indigo-600">
          <Camera className="h-6 w-6" />
        </div>
        <CardTitle className="text-2xl font-bold tracking-tight text-zinc-900">Welcome Back</CardTitle>
        <CardDescription className="text-zinc-500">
          Log in to your camera shop billing system
        </CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit}>
        <CardContent className="space-y-4">
          {error && (
            <div className="rounded-md bg-rose-500/10 p-3 text-sm text-rose-600 border border-rose-500/20">
              {error}
            </div>
          )}
          <div className="space-y-2">
            <Label htmlFor="email" className="text-zinc-750">Email Address</Label>
            <Input
              id="email"
              name="email"
              type="email"
              placeholder="you@example.com"
              required
              className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
            />
          </div>
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="password" className="text-zinc-750">Password</Label>
            </div>
            <div className="relative">
              <Input
                id="password"
                name="password"
                type={showPassword ? "text" : "password"}
                placeholder="••••••••"
                required
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
        </CardContent>
        <CardFooter>
          <Button
            type="submit"
            disabled={isPending}
            className="w-full bg-indigo-600 text-white hover:bg-indigo-500 focus:ring-indigo-500"
          >
            {isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Logging in...
              </>
            ) : (
              'Sign In'
            )}
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}
