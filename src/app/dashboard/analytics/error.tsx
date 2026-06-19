'use client'

import { Button } from '@/components/ui/button'
import { AlertCircle } from 'lucide-react'

export default function AnalyticsError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-rose-500/10">
        <AlertCircle className="h-8 w-8 text-rose-500" />
      </div>
      <div className="text-center space-y-1">
        <h2 className="text-xl font-bold text-zinc-900">Something went wrong</h2>
        <p className="text-sm text-zinc-500 max-w-md">
          Failed to load analytics data. This might be a temporary issue.
          {error.digest && (
            <span className="block mt-1 text-xs text-zinc-400">Error ID: {error.digest}</span>
          )}
        </p>
      </div>
      <Button onClick={reset} className="bg-indigo-600 text-white">
        Try again
      </Button>
    </div>
  )
}
