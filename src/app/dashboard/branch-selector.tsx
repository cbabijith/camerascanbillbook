'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { setActiveBranch } from '../actions/billing'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { toast } from 'sonner'

interface Branch {
  id: string
  name: string
}

interface BranchSelectorProps {
  branches: Branch[]
  activeBranchId: string
}

export default function BranchSelector({ branches, activeBranchId }: BranchSelectorProps) {
  const router = useRouter()
  const [loading, setLoading] = useState(false)

  const handleBranchChange = async (value: string | null) => {
    if (!value) return
    setLoading(true)
    try {
      const res = await setActiveBranch(value)
      if (res.success) {
        toast.success('Branch switched successfully')
        router.refresh()
      }
    } catch {
      toast.error('Failed to switch branch')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Select
      value={activeBranchId}
      onValueChange={handleBranchChange}
      disabled={loading}
    >
      <SelectTrigger className="w-[180px] bg-white border-zinc-200 text-zinc-900 focus:ring-indigo-500">
        <SelectValue placeholder="Select Branch">
          {branches.find((b) => b.id === activeBranchId)?.name || 'Select Branch'}
        </SelectValue>
      </SelectTrigger>
      <SelectContent className="bg-white border-zinc-200 text-zinc-900">
        {branches.map((branch) => (
          <SelectItem
            key={branch.id}
            value={branch.id}
            className="focus:bg-indigo-600 focus:text-white"
          >
            {branch.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
