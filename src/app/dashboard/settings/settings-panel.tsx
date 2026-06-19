'use client'

import { useState } from 'react'
import { createBranch, updateBranch, deleteBranch, createStaff, deleteStaff } from '../../actions/settings'
import { Card, CardContent } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Plus, Edit2, Trash2, Loader2, Building, Users, Eye, EyeOff } from 'lucide-react'
import { toast } from 'sonner'

interface Branch {
  id: string
  name: string
  address?: string
  phone?: string
  gstin?: string
  created_at: string
}

interface Staff {
  id: string
  name: string
  username: string
  branch_id?: string
  created_at: string
  branches?: {
    name: string
  }
}

interface SettingsPanelProps {
  initialBranches: Branch[]
  initialStaff: Staff[]
}

export default function SettingsPanel({ initialBranches, initialStaff }: SettingsPanelProps) {
  const [loading, setLoading] = useState(false)
  const [branches, setBranches] = useState<Branch[]>(initialBranches)
  const [staff, setStaff] = useState<Staff[]>(initialStaff)
  
  // Dialog Open/Close States
  const [isAddBranchOpen, setIsAddBranchOpen] = useState(false)
  const [isEditBranchOpen, setIsEditBranchOpen] = useState(false)
  const [isAddStaffOpen, setIsAddStaffOpen] = useState(false)
  const [showStaffPassword, setShowStaffPassword] = useState(false)

  // Edit States
  const [editingBranch, setEditingBranch] = useState<Branch | null>(null)
  const [selectedStaffBranchId, setSelectedStaffBranchId] = useState<string | null>(null)

  // Handle Add Branch
  const handleAddBranchSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const form = e.currentTarget
    setLoading(true)
    const formData = new FormData(form)

    try {
      const res = await createBranch(formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        setBranches((prev) => [...prev, res.data].sort((a, b) => a.name.localeCompare(b.name)))
        toast.success('Branch created successfully')
        setIsAddBranchOpen(false)
        form.reset()
      }
    } catch {
      toast.error('Failed to create branch')
    } finally {
      setLoading(false)
    }
  }

  // Handle Edit Branch Submit
  const handleEditBranchSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!editingBranch) return
    setLoading(true)
    const formData = new FormData(e.currentTarget)

    try {
      const res = await updateBranch(editingBranch.id, formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        setBranches((prev) => prev.map((b) => b.id === editingBranch.id ? res.data : b).sort((a, b) => a.name.localeCompare(b.name)))
        toast.success('Branch details updated successfully')
        setIsEditBranchOpen(false)
        setEditingBranch(null)
      }
    } catch {
      toast.error('Failed to update branch')
    } finally {
      setLoading(false)
    }
  }

  // Handle Delete Branch
  const handleDeleteBranch = async (id: string) => {
    if (branches.length === 1) {
      toast.error('At least one branch must remain in the system.')
      return
    }
    if (!confirm('Warning: Deleting a branch will delete all related products, customers, and invoices! Proceed?')) return

    try {
      const res = await deleteBranch(id)
      if (res.error) {
        toast.error(res.error)
      } else {
        setBranches((prev) => prev.filter((b) => b.id !== id))
        toast.success('Branch deleted successfully')
      }
    } catch {
      toast.error('Failed to delete branch')
    }
  }

  // Handle Create Staff Member
  const handleCreateStaffSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const form = e.currentTarget
    setLoading(true)
    const formData = new FormData(form)

    try {
      const res = await createStaff(formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        setStaff((prev) => [...prev, res.data].sort((a, b) => a.name.localeCompare(b.name)))
        toast.success('Staff account created successfully')
        setIsAddStaffOpen(false)
        form.reset()
        setSelectedStaffBranchId(null)
      }
    } catch {
      toast.error('Failed to create staff account')
    } finally {
      setLoading(false)
    }
  }

  // Handle Delete Staff Member
  const handleDeleteStaff = async (id: string) => {
    if (!confirm('Are you sure you want to delete this staff account? They will lose access to the system.')) return

    try {
      const res = await deleteStaff(id)
      if (res.error) {
        toast.error(res.error)
      } else {
        setStaff((prev) => prev.filter((s) => s.id !== id))
        toast.success('Staff account deleted successfully')
      }
    } catch {
      toast.error('Failed to delete staff account')
    }
  }

  return (
    <Tabs defaultValue="branches" className="space-y-6">
      <TabsList className="bg-white border border-zinc-200 text-zinc-500">
        <TabsTrigger value="branches" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white gap-2">
          <Building className="h-4 w-4" />
          Branches
        </TabsTrigger>
        <TabsTrigger value="staff" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white gap-2">
          <Users className="h-4 w-4" />
          Staff Management
        </TabsTrigger>
      </TabsList>

      {/* --- BRANCHES CONTENT --- */}
      <TabsContent value="branches" className="space-y-4 outline-none">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-semibold text-zinc-800">Shop Branches</h2>
          <Dialog open={isAddBranchOpen} onOpenChange={setIsAddBranchOpen}>
            <DialogTrigger render={
              <Button className="bg-indigo-600 hover:bg-indigo-500 text-white gap-2" />
            }>
              <Plus className="h-4 w-4" />
              Add Branch
            </DialogTrigger>
            <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Add Shop Branch</DialogTitle>
                <DialogDescription className="text-zinc-500">
                  Register a new branch location for your camera shop.
                </DialogDescription>
              </DialogHeader>
              <form onSubmit={handleAddBranchSubmit}>
                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <Label htmlFor="branch-name">Branch Name *</Label>
                    <Input id="branch-name" name="name" placeholder="Downtown Studio" required className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="branch-address">Address</Label>
                    <Input id="branch-address" name="address" placeholder="789 Market St, Downtown" className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="branch-phone">Phone Number</Label>
                      <Input id="branch-phone" name="phone" placeholder="+91 98765 43210" className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="branch-gstin">GSTIN (Optional)</Label>
                      <Input id="branch-gstin" name="gstin" placeholder="22AAAAA0000A1Z5" className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                  </div>
                </div>
                <DialogFooter>
                  <Button type="submit" disabled={loading} className="bg-indigo-600 hover:bg-indigo-500 text-white w-full">
                    {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Create Branch'}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <Card className="border-zinc-200 bg-white shadow-sm overflow-hidden">
          <CardContent className="p-0">
            <Table>
              <TableHeader className="bg-zinc-100/50">
                <TableRow className="border-zinc-200 hover:bg-transparent">
                  <TableHead className="text-zinc-500 text-xs">Branch Name</TableHead>
                  <TableHead className="text-zinc-500 text-xs">Address</TableHead>
                  <TableHead className="text-zinc-500 text-xs w-[150px]">Phone</TableHead>
                  <TableHead className="text-zinc-500 text-xs w-[180px]">GSTIN</TableHead>
                  <TableHead className="text-zinc-500 text-xs text-center w-[120px]">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {branches.map((branch) => (
                  <TableRow key={branch.id} className="border-zinc-200 hover:bg-white/10">
                    <TableCell className="font-semibold text-zinc-800">{branch.name}</TableCell>
                    <TableCell className="text-zinc-800 text-sm">{branch.address || 'N/A'}</TableCell>
                    <TableCell className="text-zinc-500 font-mono text-xs">{branch.phone || 'N/A'}</TableCell>
                    <TableCell className="text-zinc-600 font-mono text-xs">{branch.gstin || 'N/A'}</TableCell>
                    <TableCell>
                      <div className="flex items-center justify-center gap-1.5">
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            setEditingBranch(branch)
                            setIsEditOpenBranch(true)
                          }}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500 hover:text-zinc-800"
                        >
                          <Edit2 className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDeleteBranch(branch.id)}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-rose-600 hover:text-rose-300 hover:bg-rose-500/10"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        {/* Edit Branch Dialog */}
        <Dialog open={isEditBranchOpen} onOpenChange={setIsEditBranchOpen}>
          <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
            <DialogHeader>
              <DialogTitle>Edit Branch Details</DialogTitle>
              <DialogDescription className="text-zinc-500">
                Update address and contact info for this branch location.
              </DialogDescription>
            </DialogHeader>
            {editingBranch && (
              <form onSubmit={handleEditBranchSubmit}>
                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <Label htmlFor="edit-branch-name">Branch Name *</Label>
                    <Input id="edit-branch-name" name="name" defaultValue={editingBranch.name} required className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="edit-branch-address">Address</Label>
                    <Input id="edit-branch-address" name="address" defaultValue={editingBranch.address || ''} className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="edit-branch-phone">Phone Number</Label>
                      <Input id="edit-branch-phone" name="phone" defaultValue={editingBranch.phone || ''} className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="edit-branch-gstin">GSTIN (Optional)</Label>
                      <Input id="edit-branch-gstin" name="gstin" defaultValue={editingBranch.gstin || ''} className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                  </div>
                </div>
                <DialogFooter>
                  <Button type="submit" disabled={loading} className="bg-indigo-600 hover:bg-indigo-500 text-white w-full">
                    {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Save Changes'}
                  </Button>
                </DialogFooter>
              </form>
            )}
          </DialogContent>
        </Dialog>
      </TabsContent>

      {/* --- STAFF MANAGEMENT CONTENT --- */}
      <TabsContent value="staff" className="space-y-4 outline-none">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-semibold text-zinc-800">Staff Accounts</h2>
          <Dialog open={isAddStaffOpen} onOpenChange={(open) => {
            setIsAddStaffOpen(open)
            if (!open) setShowStaffPassword(false)
          }}>
            <DialogTrigger render={
              <Button className="bg-indigo-600 hover:bg-indigo-500 text-white gap-2" />
            }>
              <Plus className="h-4 w-4" />
              Add Staff Member
            </DialogTrigger>
            <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Create Staff Account</DialogTitle>
                <DialogDescription className="text-zinc-500">
                  Register a new staff member account. They will be locked to their assigned branch.
                </DialogDescription>
              </DialogHeader>
              <form onSubmit={handleCreateStaffSubmit}>
                <div className="space-y-4 py-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="staff-name">Display Name *</Label>
                      <Input id="staff-name" name="name" placeholder="Bob Jones" required className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="staff-username">Username *</Label>
                      <Input id="staff-username" name="username" placeholder="bobjones" required className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="staff-email">Auth Email Address *</Label>
                    <Input id="staff-email" name="email" type="email" placeholder="bob@shop.com" required className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="staff-password">Password *</Label>
                    <div className="relative">
                      <Input
                        id="staff-password"
                        name="password"
                        type={showStaffPassword ? "text" : "password"}
                        placeholder="••••••••"
                        required
                        minLength={6}
                        className="pr-10 border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                      />
                      <button
                        type="button"
                        onClick={() => setShowStaffPassword(!showStaffPassword)}
                        className="absolute inset-y-0 right-0 flex items-center pr-3 text-zinc-400 hover:text-zinc-600 transition-colors"
                      >
                        {showStaffPassword ? (
                          <EyeOff className="h-4 w-4" />
                        ) : (
                          <Eye className="h-4 w-4" />
                        )}
                      </button>
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="staff-branch">Assigned Branch *</Label>
                    <Select 
                      name="branchId" 
                      required 
                      value={selectedStaffBranchId} 
                      onValueChange={setSelectedStaffBranchId}
                    >
                      <SelectTrigger className="border-zinc-200 bg-white text-zinc-900">
                        <SelectValue placeholder="Select assigned branch">
                          {branches.find((b) => b.id === selectedStaffBranchId)?.name}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent className="bg-white border-zinc-200 text-zinc-900">
                        {branches.map((branch) => (
                          <SelectItem key={branch.id} value={branch.id}>
                            {branch.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <DialogFooter>
                  <Button type="submit" disabled={loading} className="bg-indigo-600 hover:bg-indigo-500 text-white w-full">
                    {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Create Account'}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <Card className="border-zinc-200 bg-white shadow-sm overflow-hidden">
          <CardContent className="p-0">
            <Table>
              <TableHeader className="bg-zinc-100/50">
                <TableRow className="border-zinc-200 hover:bg-transparent">
                  <TableHead className="text-zinc-500 text-xs">Display Name</TableHead>
                  <TableHead className="text-zinc-500 text-xs">Username</TableHead>
                  <TableHead className="text-zinc-500 text-xs">Assigned Branch</TableHead>
                  <TableHead className="text-zinc-500 text-xs text-center w-[120px]">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {staff.length === 0 ? (
                  <TableRow className="hover:bg-transparent">
                    <TableCell colSpan={4} className="h-40 text-center text-zinc-500 text-sm">
                      No staff accounts found. Create one above.
                    </TableCell>
                  </TableRow>
                ) : (
                  staff.map((member) => (
                    <TableRow key={member.id} className="border-zinc-200 hover:bg-white/10">
                      <TableCell className="font-semibold text-zinc-800">{member.name}</TableCell>
                      <TableCell className="font-mono text-zinc-500 text-sm">{member.username}</TableCell>
                      <TableCell className="text-zinc-800 text-sm">{member.branches?.name || 'Unassigned'}</TableCell>
                      <TableCell>
                        <div className="flex items-center justify-center">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => handleDeleteStaff(member.id)}
                            className="h-7 w-7 border border-zinc-200 hover:bg-white text-rose-600 hover:text-rose-300 hover:bg-rose-500/10"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </TabsContent>
    </Tabs>
  )

  // Quick helper to bypass typescript issue with editing state
  function setIsEditOpenBranch(open: boolean) {
    setIsEditBranchOpen(open)
  }
}
