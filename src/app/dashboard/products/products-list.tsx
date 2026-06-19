'use client'

import { useState } from 'react'
import { createProduct, updateProduct, deleteProduct } from '../../actions/settings'
import { Card, CardContent } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Search, Plus, Edit2, Trash2, Loader2, ChevronDown, ChevronUp } from 'lucide-react'
import { format } from 'date-fns'
import { toast } from 'sonner'
import { formatINR } from '@/lib/utils'

interface Product {
  id: string
  name: string
  brand?: string
  category?: string
  sku: string
  selling_price: number
  mrp?: number | null
  gst_rate: number
  created_at: string
  created_by?: string
  updated_at: string
  updated_by?: string
  creator?: { name: string } | null
}

interface ProductsListProps {
  initialProducts: Product[]
}

export default function ProductsList({ initialProducts }: ProductsListProps) {
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [editingProduct, setEditingProduct] = useState<Product | null>(null)
  
  const [isAddOpen, setIsAddOpen] = useState(false)
  const [isEditOpen, setIsEditOpen] = useState(false)
  const [showAddOptional, setShowAddOptional] = useState(false)
  const [showEditOptional, setShowEditOptional] = useState(false)

  // Filter products
  const filteredProducts = initialProducts.filter((product) => {
    const term = search.toLowerCase()
    return (
      product.name.toLowerCase().includes(term) ||
      (product.brand && product.brand.toLowerCase().includes(term)) ||
      product.sku.toLowerCase().includes(term)
    )
  })

  // Handle Create Product
  const handleCreateProduct = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const form = e.currentTarget
    setLoading(true)
    const formData = new FormData(form)

    try {
      const res = await createProduct(formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Product created successfully')
        setIsAddOpen(false)
        form.reset()
      }
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to create product')
    } finally {
      setLoading(false)
    }
  }

  // Handle Edit Submit
  const handleEditProduct = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!editingProduct) return
    setLoading(true)
    const formData = new FormData(e.currentTarget)

    try {
      const res = await updateProduct(editingProduct.id, formData)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Product updated successfully')
        setIsEditOpen(false)
        setEditingProduct(null)
      }
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to update product')
    } finally {
      setLoading(false)
    }
  }

  // Handle Delete Product
  const handleDeleteProduct = async (id: string) => {
    if (!confirm('Are you sure you want to delete this product from the catalogue?')) return

    try {
      const res = await deleteProduct(id)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Product deleted successfully')
      }
    } catch {
      toast.error('Failed to delete product')
    }
  }

  return (
    <div className="space-y-4">
      {/* Search and Add Header */}
      <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
        <div className="relative w-full sm:max-w-sm">
          <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-500" />
          <Input
            placeholder="Search by Name, Serial No., or Brand..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 border-zinc-200 bg-zinc-100 text-zinc-900 focus-visible:ring-indigo-600"
          />
        </div>

        {/* Add Product Dialog */}
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger render={
            <Button className="bg-indigo-600 hover:bg-indigo-500 text-white gap-2 w-full sm:w-auto" />
          }>
            <Plus className="h-4 w-4" />
            Add Product
          </DialogTrigger>
          <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
            <DialogHeader>
              <DialogTitle>Add New Product</DialogTitle>
              <DialogDescription className="text-zinc-500">
                Register a new camera or accessory in the active branch catalogue.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateProduct}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="name">Product Name *</Label>
                  <Input id="name" name="name" placeholder="Sony Alpha 7R V" required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="sku">Serial Number *</Label>
                  <Input id="sku" name="sku" placeholder="Enter serial number" required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="sellingPrice">Selling Price *</Label>
                    <Input id="sellingPrice" name="sellingPrice" type="number" step="0.01" placeholder="3899.00" required className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="mrp">MRP (Optional)</Label>
                    <Input id="mrp" name="mrp" type="number" step="0.01" placeholder="4999.00" className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                </div>

                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowAddOptional(!showAddOptional)}
                  className="w-full text-zinc-500 hover:text-zinc-800 gap-1"
                >
                  {showAddOptional ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
                  {showAddOptional ? 'Hide' : 'Show'} optional fields (Brand, Category)
                </Button>

                {showAddOptional && (
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="brand">Brand (Optional)</Label>
                      <Input id="brand" name="brand" placeholder="Sony" className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="category">Category (Optional)</Label>
                      <Input id="category" name="category" placeholder="Camera" className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                  </div>
                )}
              </div>
              <DialogFooter>
                <Button type="submit" disabled={loading} className="bg-indigo-600 hover:bg-indigo-500 text-white w-full">
                  {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Save Product'}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Catalogue List table */}
      <Card className="border-zinc-200 bg-white shadow-sm overflow-hidden hidden md:block">
        <CardContent className="p-0">
          <Table>
            <TableHeader className="bg-zinc-100/50">
              <TableRow className="border-zinc-200 hover:bg-transparent">
                <TableHead className="text-zinc-500 text-xs">Product Details</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[120px]">Serial No.</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[120px]">Category</TableHead>
                <TableHead className="text-zinc-500 text-xs text-right w-[110px]">Price</TableHead>
                <TableHead className="text-zinc-500 text-xs text-right w-[110px]">MRP</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[150px]">Audit Logs</TableHead>
                <TableHead className="text-zinc-500 text-xs text-center w-[120px]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredProducts.length === 0 ? (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={7} className="h-40 text-center text-zinc-500 text-sm">
                    No products found in the catalogue.
                  </TableCell>
                </TableRow>
              ) : (
                filteredProducts.map((product) => (
                  <TableRow key={product.id} className="border-zinc-200 hover:bg-white/10">
                    <TableCell>
                       <div className="font-semibold text-zinc-800">{product.name}</div>
                      {product.brand && <div className="text-[10px] text-zinc-500">{product.brand}</div>}
                    </TableCell>
                    <TableCell className="font-mono text-xs text-zinc-500">{product.sku}</TableCell>
                    <TableCell className="text-zinc-800 text-sm">{product.category || '-'}</TableCell>
                    <TableCell className="text-right font-semibold text-indigo-600">{formatINR(product.selling_price)}</TableCell>
                    <TableCell className="text-right text-zinc-500 text-sm">{product.mrp ? formatINR(product.mrp) : '-'}</TableCell>
                    <TableCell>
                      <div className="text-[10px] text-zinc-500">
                        <div>C: {product.creator?.name || 'System'}</div>
                        <div className="text-zinc-500">{format(new Date(product.created_at), 'dd-MMM-yy')}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center justify-center gap-1.5">
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            setEditingProduct(product)
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
                          onClick={() => handleDeleteProduct(product.id)}
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
        {filteredProducts.length === 0 ? (
          <div className="p-8 text-center text-zinc-500 border border-dashed border-zinc-200 rounded-lg bg-white">
            No products found in the catalogue.
          </div>
        ) : (
          filteredProducts.map((product) => (
            <Card key={product.id} className="border-zinc-200 bg-white shadow-sm">
              <CardContent className="p-4 space-y-3">
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="font-bold text-zinc-800 text-sm">{product.name}</h4>
                    {product.brand && <span className="text-zinc-400 text-[10px] block">{product.brand}</span>}
                  </div>
                  <div className="flex items-center gap-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => {
                        setEditingProduct(product)
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
                      onClick={() => handleDeleteProduct(product.id)}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-rose-600 hover:bg-rose-50/10"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 text-xs border-t border-zinc-100 pt-2">
                  <div>
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Serial No.</span>
                    <span className="font-mono text-zinc-650 block text-[10px]">{product.sku}</span>
                  </div>
                  <div>
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Price</span>
                    <span className="font-semibold text-indigo-600">{formatINR(product.selling_price)}</span>
                  </div>
                  <div className="text-right">
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">MRP</span>
                    <span className="text-zinc-500">{product.mrp ? formatINR(product.mrp) : '-'}</span>
                  </div>
                </div>

                <div className="flex justify-between items-center text-[10px] text-zinc-400 pt-2 border-t border-zinc-100">
                  <span>Category: {product.category || '-'}</span>
                  <span>Created by: {product.creator?.name || 'System'}</span>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Edit Product Dialog */}
      <Dialog open={isEditOpen} onOpenChange={setIsEditOpen}>
        <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Edit Product details</DialogTitle>
            <DialogDescription className="text-zinc-500">
              Update the catalogue entry details for this product.
            </DialogDescription>
          </DialogHeader>
          {editingProduct && (
            <form onSubmit={handleEditProduct}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="edit-name">Product Name *</Label>
                  <Input id="edit-name" name="name" defaultValue={editingProduct.name} required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit-sku">Serial Number *</Label>
                  <Input id="edit-sku" name="sku" defaultValue={editingProduct.sku} required className="border-zinc-200 bg-white text-zinc-900" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="edit-sellingPrice">Selling Price *</Label>
                    <Input id="edit-sellingPrice" name="sellingPrice" type="number" step="0.01" defaultValue={editingProduct.selling_price} required className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="edit-mrp">MRP (Optional)</Label>
                    <Input id="edit-mrp" name="mrp" type="number" step="0.01" defaultValue={editingProduct.mrp ?? ''} className="border-zinc-200 bg-white text-zinc-900" />
                  </div>
                </div>

                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowEditOptional(!showEditOptional)}
                  className="w-full text-zinc-500 hover:text-zinc-800 gap-1"
                >
                  {showEditOptional ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
                  {showEditOptional ? 'Hide' : 'Show'} optional fields (Brand, Category)
                </Button>

                {showEditOptional && (
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="edit-brand">Brand (Optional)</Label>
                      <Input id="edit-brand" name="brand" defaultValue={editingProduct.brand || ''} className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="edit-category">Category (Optional)</Label>
                      <Input id="edit-category" name="category" defaultValue={editingProduct.category || ''} className="border-zinc-200 bg-white text-zinc-900" />
                    </div>
                  </div>
                )}
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
