'use client'

import { useState } from 'react'
import { createCustomer, updateCustomer, deleteCustomer } from '../../actions/settings'
import { Card, CardContent } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Search, Plus, Edit2, Trash2, Loader2 } from 'lucide-react'
import { format } from 'date-fns'
import { toast } from 'sonner'

interface Customer {
  id: string
  name: string
  phone: string
  email?: string
  address?: string
  created_at: string
  created_by?: string
  updated_at: string
  updated_by?: string
  creator?: { name: string } | null
}

interface CustomersListProps {
  initialCustomers: Customer[]
}

export default function CustomersList({ initialCustomers }: CustomersListProps) {
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null)
  
  const [isAddOpen, setIsAddOpen] = useState(false)
  const [isEditOpen, setIsEditOpen] = useState(false)

  // Filter customers
  const filteredCustomers = initialCustomers.filter((cust) => {
    const term = search.toLowerCase()
    return (
      cust.name.toLowerCase().includes(term) ||
      cust.phone.includes(term) ||
      (cust.email && cust.email.toLowerCase().includes(term))
    )
  })

  // Handle Create Customer
  const handleCreateCustomer = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const form = e.currentTarget
    setLoading(true)
    const formData = new FormData(form)

    try {
      const res = await createCustomer(formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Customer created successfully')
        setIsAddOpen(false)
        form.reset()
      }
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to create customer')
    } finally {
      setLoading(false)
    }
  }

  // Handle Edit Submit
  const handleEditCustomer = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!editingCustomer) return
    setLoading(true)
    const formData = new FormData(e.currentTarget)

    try {
      const res = await updateCustomer(editingCustomer.id, formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Customer updated successfully')
        setIsEditOpen(false)
        setEditingCustomer(null)
      }
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to update customer')
    } finally {
      setLoading(false)
    }
  }

  // Handle Delete Customer
  const handleDeleteCustomer = async (id: string) => {
    if (!confirm('Are you sure you want to delete this customer? This will remove their record from this branch.')) return

    try {
      const res = await deleteCustomer(id)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Customer deleted successfully')
      }
    } catch {
      toast.error('Failed to delete customer')
    }
  }

  return (
    <div className="space-y-4">
      {/* Search and Add Header */}
      <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
        <div className="relative w-full sm:max-w-sm">
          <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-500" />
          <Input
            placeholder="Search by Name, Phone, or Email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 border-zinc-200 bg-zinc-100 text-zinc-900 focus-visible:ring-indigo-600"
          />
        </div>

        {/* Add Customer Dialog */}
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger render={
            <Button className="bg-indigo-600 hover:bg-indigo-500 text-white gap-2 w-full sm:w-auto" />
          }>
            <Plus className="h-4 w-4" />
            Add Customer
          </DialogTrigger>
          <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
            <DialogHeader>
              <DialogTitle>Add New Customer</DialogTitle>
              <DialogDescription className="text-zinc-500">
                Register a new client contact for this branch.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateCustomer}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="name">Customer Full Name *</Label>
                  <Input id="name" name="name" placeholder="Alice Smith" required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phone">Phone Number *</Label>
                  <Input id="phone" name="phone" placeholder="+91 98765 43210" required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">Email Address</Label>
                  <Input id="email" name="email" type="email" placeholder="alice@example.com" className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="address">Shop/Home Address</Label>
                  <Input id="address" name="address" placeholder="456 Main St, Suite 100" className="border-zinc-200 bg-white text-zinc-900" />
                </div>
              </div>
              <DialogFooter>
                <Button type="submit" disabled={loading} className="bg-indigo-600 hover:bg-indigo-500 text-white w-full">
                  {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Save Customer'}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Customer List table */}
      <Card className="border-zinc-200 bg-white shadow-sm overflow-hidden hidden md:block">
        <CardContent className="p-0">
          <Table>
            <TableHeader className="bg-zinc-100/50">
              <TableRow className="border-zinc-200 hover:bg-transparent">
                <TableHead className="text-zinc-500 text-xs">Customer Name</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[150px]">Phone</TableHead>
                <TableHead className="text-zinc-500 text-xs">Email Address</TableHead>
                <TableHead className="text-zinc-500 text-xs">Address</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[150px]">Audit Logs</TableHead>
                <TableHead className="text-zinc-500 text-xs text-center w-[120px]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredCustomers.length === 0 ? (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={6} className="h-40 text-center text-zinc-500 text-sm">
                    No customers found.
                  </TableCell>
                </TableRow>
              ) : (
                filteredCustomers.map((cust) => (
                  <TableRow key={cust.id} className="border-zinc-200 hover:bg-white/10">
                    <TableCell className="font-semibold text-zinc-800">{cust.name}</TableCell>
                    <TableCell className="font-mono text-xs text-zinc-500">{cust.phone}</TableCell>
                    <TableCell className="text-zinc-800 text-sm">{cust.email || 'N/A'}</TableCell>
                    <TableCell className="text-zinc-800 text-sm truncate max-w-[200px]">{cust.address || 'N/A'}</TableCell>
                    <TableCell>
                      <div className="text-[10px] text-zinc-500">
                        <div>C: {cust.creator?.name || 'System'}</div>
                        <div className="text-zinc-500">{format(new Date(cust.created_at), 'dd-MMM-yy')}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center justify-center gap-1.5">
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            setEditingCustomer(cust)
                            setIsEditOpen(true)
                          }}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500 hover:text-zinc-800"
                        >
                          <Edit2 className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDeleteCustomer(cust.id)}
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

      {/* Mobile Card List View */}
      <div className="space-y-3 md:hidden">
        {filteredCustomers.length === 0 ? (
          <div className="p-8 text-center text-zinc-500 border border-dashed border-zinc-200 rounded-lg bg-white">
            No customers found.
          </div>
        ) : (
          filteredCustomers.map((cust) => (
            <Card key={cust.id} className="border-zinc-200 bg-white shadow-sm">
              <CardContent className="p-4 space-y-3">
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="font-bold text-zinc-800 text-sm">{cust.name}</h4>
                    <span className="text-zinc-500 font-mono text-xs block mt-0.5">{cust.phone}</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => {
                        setEditingCustomer(cust)
                        setIsEditOpen(true)
                      }}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-zinc-500"
                    >
                      <Edit2 className="h-3.5 w-3.5" />
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDeleteCustomer(cust.id)}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-rose-600 hover:bg-rose-50/10"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2 text-xs border-t border-zinc-100 pt-2 text-zinc-650">
                  <div>
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Email</span>
                    <span className="truncate block max-w-full">{cust.email || 'N/A'}</span>
                  </div>
                  <div>
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Address</span>
                    <span className="truncate block max-w-full">{cust.address || 'N/A'}</span>
                  </div>
                </div>

                <div className="flex justify-between items-center text-[10px] text-zinc-400 pt-2 border-t border-zinc-100">
                  <span>Created by: {cust.creator?.name || 'System'}</span>
                  <span>{format(new Date(cust.created_at), 'dd-MMM-yyyy')}</span>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Edit Customer Dialog */}
      <Dialog open={isEditOpen} onOpenChange={setIsEditOpen}>
        <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Edit Customer details</DialogTitle>
            <DialogDescription className="text-zinc-500">
              Update contact info for this customer.
            </DialogDescription>
          </DialogHeader>
          {editingCustomer && (
            <form onSubmit={handleEditCustomer}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="edit-name">Customer Full Name *</Label>
                  <Input id="edit-name" name="name" defaultValue={editingCustomer.name} required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit-phone">Phone Number *</Label>
                  <Input id="edit-phone" name="phone" defaultValue={editingCustomer.phone} required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit-email">Email Address</Label>
                  <Input id="edit-email" name="email" type="email" defaultValue={editingCustomer.email || ''} className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit-address">Address</Label>
                  <Input id="edit-address" name="address" defaultValue={editingCustomer.address || ''} className="border-zinc-200 bg-white text-zinc-900" />
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
    </div>
  )
}
