'use client'

import { useState, useEffect, useRef, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { searchCustomers, searchProducts, createBill } from '../actions/billing'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { Plus, Minus, Trash2, Search, UserPlus, PackagePlus, Loader2, ArrowRight, ChevronDown, ChevronUp } from 'lucide-react'
import { toast } from 'sonner'
import { formatINR } from '@/lib/utils'

interface Customer {
  id: string
  name: string
  phone: string
  email?: string
  address?: string
}

interface Product {
  id: string
  name: string
  brand: string
  category: string
  sku: string
  selling_price: number
  mrp?: number | null
}

interface SelectedItem {
  productId: string | 'new'
  name: string
  brand: string
  category: string
  sku: string
  sellingPrice: number
  mrp?: number | null
  qty: number
}

export default function BillingForm() {
  const router = useRouter()
  const [isPending, startTransition] = useTransition()

  // Customer State
  const [customerSearch, setCustomerSearch] = useState('')
  const [customerResults, setCustomerResults] = useState<Customer[]>([])
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
  const [isNewCustomer, setIsNewCustomer] = useState(false)
  const [newCustomer, setNewCustomer] = useState({
    name: '',
    phone: '',
    email: '',
    address: ''
  })
  const [showCustomerSearch, setShowCustomerSearch] = useState(false)
  const customerSearchRef = useRef<HTMLDivElement>(null)

  // Product Search State
  const [productSearch, setProductSearch] = useState('')
  const [productResults, setProductResults] = useState<Product[]>([])
  const [showProductSearch, setShowProductSearch] = useState(false)
  const productSearchRef = useRef<HTMLDivElement>(null)

  // Items added to bill
  const [billItems, setBillItems] = useState<SelectedItem[]>([])

  // Payment status
  const [paymentStatus, setPaymentStatus] = useState<'paid' | 'unpaid'>('paid')

  // Inline Custom Product State
  const [isCustomProductOpen, setIsCustomProductOpen] = useState(false)
  const [showOptionalFields, setShowOptionalFields] = useState(false)
  const [customProduct, setCustomProduct] = useState({
    name: '',
    brand: '',
    category: '',
    sku: '',
    sellingPrice: '',
    mrp: ''
  })

  // Handle outside clicks to close searches
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (customerSearchRef.current && !customerSearchRef.current.contains(event.target as Node)) {
        setShowCustomerSearch(false)
      }
      if (productSearchRef.current && !productSearchRef.current.contains(event.target as Node)) {
        setShowProductSearch(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Trigger Customer Search
  useEffect(() => {
    if (customerSearch.trim().length >= 1) {
      const delayDebounce = setTimeout(async () => {
        const results = await searchCustomers(customerSearch)
        setCustomerResults(results)
        setShowCustomerSearch(true)
      }, 300)
      return () => clearTimeout(delayDebounce)
    } else {
      setCustomerResults([])
    }
  }, [customerSearch])

  // Trigger Product Search
  useEffect(() => {
    if (productSearch.trim().length >= 1) {
      const delayDebounce = setTimeout(async () => {
        const results = await searchProducts(productSearch)
        setProductResults(results)
        setShowProductSearch(true)
      }, 300)
      return () => clearTimeout(delayDebounce)
    } else {
      setProductResults([])
    }
  }, [productSearch])

  // Select Customer
  const handleSelectCustomer = (customer: Customer) => {
    setSelectedCustomer(customer)
    setIsNewCustomer(false)
    setCustomerSearch('')
    setShowCustomerSearch(false)
  }

  // Clear Selected Customer
  const handleClearCustomer = () => {
    setSelectedCustomer(null)
    setIsNewCustomer(false)
    setNewCustomer({ name: '', phone: '', email: '', address: '' })
  }

  // Select Product
  const handleSelectProduct = (product: Product) => {
    // Check if product is already in bill
    const existingIndex = billItems.findIndex((item) => item.productId === product.id)
    if (existingIndex > -1) {
      const updated = [...billItems]
      updated[existingIndex].qty += 1
      setBillItems(updated)
    } else {
      setBillItems([
        ...billItems,
        {
          productId: product.id,
          name: product.name,
          brand: product.brand || '',
          category: product.category || '',
          sku: product.sku,
          sellingPrice: Number(product.selling_price),
          mrp: product.mrp ?? null,
          qty: 1
        }
      ])
    }
    setProductSearch('')
    setShowProductSearch(false)
    toast.success(`${product.name} added to invoice`)
  }

  // Handle custom inline product submit
  const handleAddCustomProduct = (e: React.FormEvent) => {
    e.preventDefault()
    if (!customProduct.name || !customProduct.sku || !customProduct.sellingPrice) {
      toast.error('Please fill in required fields: Name, Serial Number, and Selling Price.')
      return
    }

    setBillItems([
      ...billItems,
      {
        productId: 'new',
        name: customProduct.name,
        brand: customProduct.brand || '',
        category: customProduct.category || '',
        sku: customProduct.sku,
        sellingPrice: parseFloat(customProduct.sellingPrice),
        mrp: customProduct.mrp ? parseFloat(customProduct.mrp) : null,
        qty: 1
      }
    ])

    // Reset Custom Product Form
    setCustomProduct({
      name: '',
      brand: '',
      category: '',
      sku: '',
      sellingPrice: '',
      mrp: ''
    })
    setShowOptionalFields(false)
    setIsCustomProductOpen(false)
    toast.success('Custom product added inline to bill')
  }

  // Modify Item Qty
  const handleUpdateQty = (index: number, newQty: number) => {
    if (newQty < 1) return
    const updated = [...billItems]
    updated[index].qty = newQty
    setBillItems(updated)
  }

  // Edit any field of a bill item inline
  const handleEditItem = (index: number, field: keyof SelectedItem, value: string | number) => {
    const updated = [...billItems]
    if (field === 'qty' || field === 'sellingPrice') {
      const numVal = typeof value === 'string' ? parseFloat(value) : value
      if (field === 'qty' && (isNaN(numVal) || numVal < 1)) return
      if (field === 'sellingPrice' && (isNaN(numVal) || numVal < 0)) return
      updated[index] = { ...updated[index], [field]: numVal }
    } else {
      updated[index] = { ...updated[index], [field]: value }
    }
    setBillItems(updated)
  }

  // Delete Item
  const handleDeleteItem = (index: number) => {
    setBillItems(billItems.filter((_, i) => i !== index))
  }

  // Calculation formulas
  const calculateTotals = () => {
    let total = 0

    billItems.forEach((item) => {
      total += item.sellingPrice * item.qty
    })

    return {
      total: Math.round(total * 100) / 100
    }
  }

  const totals = calculateTotals()

  // Handle final invoice submission
  const handleSubmitBill = () => {
    if (billItems.length === 0) {
      toast.error('Please add at least one product to the bill.')
      return
    }

    if (!isNewCustomer && !selectedCustomer) {
      toast.error('Please select a customer or create a new one.')
      return
    }

    if (isNewCustomer && (!newCustomer.name || !newCustomer.phone)) {
      toast.error('New customer Name and Phone are required.')
      return
    }

    startTransition(async () => {
      try {
        const payload = {
          customerId: isNewCustomer ? ('new' as const) : selectedCustomer!.id,
          customerName: isNewCustomer ? newCustomer.name : selectedCustomer!.name,
          customerPhone: isNewCustomer ? newCustomer.phone : selectedCustomer!.phone,
          customerEmail: isNewCustomer ? newCustomer.email : selectedCustomer!.email,
          customerAddress: isNewCustomer ? newCustomer.address : selectedCustomer!.address,
          items: billItems.map((item) => ({
            ...item
          })),
          paymentStatus
        }

        const res = await createBill(payload)

        if (res.error) {
          toast.error(res.error)
        } else {
          toast.success('Invoice created successfully!')
          router.push('/dashboard/bills')
        }
      } catch (error: unknown) {
        toast.error(error instanceof Error ? error.message : 'Failed to create bill.')
      }
    })
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Left panel: Customer details */}
      <div className="lg:col-span-1 space-y-6 order-2 lg:order-1">
        <Card className="border-zinc-200 bg-white shadow-sm">
          <CardHeader className="border-b border-zinc-200 pb-4">
            <CardTitle className="text-lg font-semibold text-zinc-900 flex items-center justify-between">
              <span>Customer Details</span>
              {selectedCustomer || isNewCustomer ? (
                <Button variant="ghost" size="sm" onClick={handleClearCustomer} className="text-xs text-zinc-500 hover:text-zinc-800">
                  Reset
                </Button>
              ) : null}
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-6 space-y-4">
            {!selectedCustomer && !isNewCustomer ? (
              <div className="space-y-4">
                <div ref={customerSearchRef} className="relative">
                  <Label htmlFor="cust-search" className="text-zinc-700 text-xs font-semibold mb-2 block">Search Existing Customer</Label>
                  <div className="relative">
                    <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-500" />
                    <Input
                      id="cust-search"
                      placeholder="Type name or phone number..."
                      value={customerSearch}
                      onChange={(e) => setCustomerSearch(e.target.value)}
                      className="pl-9 border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                    />
                  </div>

                  {/* Customer Results Dropdown */}
                  {showCustomerSearch && customerResults.length > 0 && (
                    <div className="absolute z-20 w-full mt-1 border border-zinc-200 bg-white rounded-md shadow-lg max-h-60 overflow-y-auto">
                      {customerResults.map((cust) => (
                        <div
                          key={cust.id}
                          onClick={() => handleSelectCustomer(cust)}
                          className="px-4 py-2.5 hover:bg-zinc-100 cursor-pointer text-sm border-b border-zinc-200/50 last:border-0"
                        >
                          <div className="font-medium text-zinc-800">{cust.name}</div>
                          <div className="text-xs text-zinc-500">{cust.phone} {cust.email ? `• ${cust.email}` : ''}</div>
                        </div>
                      ))}
                    </div>
                  )}

                  {showCustomerSearch && customerSearch.trim().length > 0 && customerResults.length === 0 && (
                    <div className="absolute z-20 w-full mt-1 p-3 border border-zinc-200 bg-white rounded-md text-zinc-500 text-xs text-center">
                      No customer found matching "{customerSearch}"
                    </div>
                  )}
                </div>

                <div className="flex items-center justify-center py-2">
                  <span className="h-px w-full bg-white" />
                  <span className="px-3 text-xs text-zinc-500">OR</span>
                  <span className="h-px w-full bg-white" />
                </div>

                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsNewCustomer(true)}
                  className="w-full border-zinc-200 hover:bg-white text-zinc-700 gap-2"
                >
                  <UserPlus className="h-4 w-4" />
                  New Customer Inline
                </Button>
              </div>
            ) : selectedCustomer ? (
              /* Selected Customer Card */
              <div className="p-4 rounded-md border border-indigo-200 bg-indigo-50/30 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold uppercase tracking-wider text-indigo-600">Selected Customer</span>
                  <Badge className="bg-indigo-600/10 text-indigo-600 border border-indigo-200">Saved</Badge>
                </div>
                <h4 className="font-bold text-zinc-900 text-lg">{selectedCustomer.name}</h4>
                <p className="text-sm text-zinc-700">Phone: {selectedCustomer.phone}</p>
                {selectedCustomer.email && <p className="text-sm text-zinc-500">Email: {selectedCustomer.email}</p>}
                {selectedCustomer.address && <p className="text-sm text-zinc-600 mt-1">Addr: {selectedCustomer.address}</p>}
              </div>
            ) : (
              /* New Customer Fields */
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold uppercase tracking-wider text-emerald-600">New Customer Info</span>
                  <Badge className="bg-emerald-500/10 text-emerald-600 border border-emerald-200">Auto-save</Badge>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="cust-name" className="text-zinc-350 text-xs">Customer Name *</Label>
                  <Input
                    id="cust-name"
                    placeholder="Enter full name"
                    value={newCustomer.name}
                    onChange={(e) => setNewCustomer({ ...newCustomer, name: e.target.value })}
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="cust-phone" className="text-zinc-350 text-xs">Phone Number *</Label>
                  <Input
                    id="cust-phone"
                    placeholder="Enter mobile number"
                    value={newCustomer.phone}
                    onChange={(e) => setNewCustomer({ ...newCustomer, phone: e.target.value })}
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="cust-email" className="text-zinc-355 text-xs">Email (Optional)</Label>
                  <Input
                    id="cust-email"
                    type="email"
                    placeholder="name@email.com"
                    value={newCustomer.email}
                    onChange={(e) => setNewCustomer({ ...newCustomer, email: e.target.value })}
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="cust-addr" className="text-zinc-355 text-xs">Address (Optional)</Label>
                  <Input
                    id="cust-addr"
                    placeholder="Enter address"
                    value={newCustomer.address}
                    onChange={(e) => setNewCustomer({ ...newCustomer, address: e.target.value })}
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  />
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Totals and Submit */}
        <Card className="border-zinc-200 bg-white shadow-sm">
          <CardContent className="pt-6 space-y-4">
            <div className="space-y-2">
              <Label className="text-zinc-700 text-xs">Payment Status</Label>
              <Select value={paymentStatus} onValueChange={(val) => val && setPaymentStatus(val as 'paid' | 'unpaid')}>
                <SelectTrigger className="border-zinc-200 bg-white text-zinc-900 focus:ring-indigo-500">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="bg-white border-zinc-200 text-zinc-900">
                  <SelectItem value="paid">Paid</SelectItem>
                  <SelectItem value="unpaid">Unpaid</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="border-t border-zinc-200 pt-4 space-y-2">
              <div className="flex justify-between text-base font-bold text-zinc-900 pt-2 border-t border-zinc-200/50">
                <span>Total Amount</span>
                <span>{formatINR(totals.total)}</span>
              </div>
            </div>

            <Button
              type="button"
              disabled={isPending}
              onClick={handleSubmitBill}
              className="w-full mt-2 bg-indigo-600 hover:bg-indigo-500 text-white gap-2"
            >
              {isPending ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Generating Invoice...
                </>
              ) : (
                <>
                  Generate Bill & Print
                  <ArrowRight className="h-4 w-4" />
                </>
              )}
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Right panel: Search and Items table */}
      <div className="lg:col-span-2 space-y-6 order-1 lg:order-2">
        <Card className="border-zinc-200 bg-white shadow-sm">
          <CardHeader className="border-b border-zinc-200 pb-4">
            <CardTitle className="text-lg font-semibold text-zinc-900 flex items-center justify-between">
              <span>Invoice Items</span>
              <Dialog open={isCustomProductOpen} onOpenChange={setIsCustomProductOpen}>
                <DialogTrigger render={
                  <Button variant="outline" size="sm" className="border-zinc-200 text-zinc-700 hover:bg-white gap-1.5" />
                }>
                  <PackagePlus className="h-3.5 w-3.5 text-indigo-600" />
                  Add Custom Product Inline
                </DialogTrigger>
                <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[425px]">
                  <DialogHeader>
                    <DialogTitle>Add Custom Product</DialogTitle>
                    <DialogDescription className="text-zinc-500">
                      Enter details of the custom product. It will be added to the invoice and saved to the catalogue.
                    </DialogDescription>
                  </DialogHeader>
                  <form onSubmit={handleAddCustomProduct}>
                    <div className="space-y-4 py-4">
                      <div className="space-y-2">
                        <Label htmlFor="prod-name">Product Name *</Label>
                        <Input
                          id="prod-name"
                          placeholder="e.g. Sony A7 IV Camera"
                          value={customProduct.name}
                          onChange={(e) => setCustomProduct({ ...customProduct, name: e.target.value })}
                          className="border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                          required
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="prod-sku">Serial Number *</Label>
                        <Input
                          id="prod-sku"
                          placeholder="Enter serial number"
                          value={customProduct.sku}
                          onChange={(e) => setCustomProduct({ ...customProduct, sku: e.target.value })}
                          className="border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                          required
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="prod-price">Selling Price *</Label>
                          <Input
                            id="prod-price"
                            type="number"
                            step="0.01"
                            placeholder="1200.00"
                            value={customProduct.sellingPrice}
                            onChange={(e) => setCustomProduct({ ...customProduct, sellingPrice: e.target.value })}
                            className="border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                            required
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="prod-mrp">MRP (Optional)</Label>
                          <Input
                            id="prod-mrp"
                            type="number"
                            step="0.01"
                            placeholder="1500.00"
                            value={customProduct.mrp}
                            onChange={(e) => setCustomProduct({ ...customProduct, mrp: e.target.value })}
                            className="border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                          />
                        </div>
                      </div>

                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => setShowOptionalFields(!showOptionalFields)}
                        className="w-full text-zinc-500 hover:text-zinc-800 gap-1"
                      >
                        {showOptionalFields ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
                        {showOptionalFields ? 'Hide' : 'Show'} optional fields (Brand, Category)
                      </Button>

                      {showOptionalFields && (
                        <div className="grid grid-cols-2 gap-4">
                          <div className="space-y-2">
                            <Label htmlFor="prod-brand">Brand (Optional)</Label>
                            <Input
                              id="prod-brand"
                              placeholder="e.g. Sony"
                              value={customProduct.brand}
                              onChange={(e) => setCustomProduct({ ...customProduct, brand: e.target.value })}
                              className="border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="prod-cat">Category (Optional)</Label>
                            <Input
                              id="prod-cat"
                              placeholder="e.g. Camera"
                              value={customProduct.category}
                              onChange={(e) => setCustomProduct({ ...customProduct, category: e.target.value })}
                              className="border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                            />
                          </div>
                        </div>
                      )}
                    </div>
                    <DialogFooter>
                      <Button type="submit" className="bg-indigo-600 hover:bg-indigo-500 text-white w-full">
                        Add to Bill
                      </Button>
                    </DialogFooter>
                  </form>
                </DialogContent>
              </Dialog>
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-6 space-y-6">
            {/* Product Search Row */}
            <div ref={productSearchRef} className="relative">
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-500" />
                <Input
                  placeholder="Search products by Name, Serial No. or Brand to add..."
                  value={productSearch}
                  onChange={(e) => setProductSearch(e.target.value)}
                  className="pl-9 border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600"
                />
              </div>

              {/* Product Results Dropdown */}
              {showProductSearch && productResults.length > 0 && (
                <div className="absolute z-20 w-full mt-1 border border-zinc-200 bg-white rounded-md shadow-lg max-h-60 overflow-y-auto">
                  {productResults.map((product) => (
                    <div
                      key={product.id}
                      onClick={() => handleSelectProduct(product)}
                      className="px-4 py-2.5 hover:bg-zinc-100 cursor-pointer text-sm border-b border-zinc-200/50 last:border-0 flex justify-between items-center"
                    >
                      <div>
                        <div className="font-medium text-zinc-800">{product.name}</div>
                        <div className="text-xs text-zinc-500">SN: {product.sku} • Brand: {product.brand || 'N/A'}</div>
                      </div>
                      <div className="text-right">
                        <div className="font-semibold text-indigo-600">{formatINR(product.selling_price)}</div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {showProductSearch && productSearch.trim().length > 0 && productResults.length === 0 && (
                <div className="absolute z-20 w-full mt-1 p-4 border border-zinc-200 bg-white rounded-md text-zinc-500 text-xs text-center flex flex-col items-center gap-2">
                  <span>No product found matching "{productSearch}"</span>
                  <Button
                    type="button"
                    size="sm"
                    variant="link"
                    className="text-indigo-600 hover:text-indigo-300"
                    onClick={() => {
                      setCustomProduct({ ...customProduct, name: productSearch, sku: `SN-${Date.now()}` })
                      setIsCustomProductOpen(true)
                    }}
                  >
                    Create new product inline
                  </Button>
                </div>
              )}
            </div>

            {/* Items Table */}
            <div className="border border-zinc-200 rounded-md overflow-hidden bg-zinc-50 hidden md:block">
              <Table>
                <TableHeader className="bg-zinc-100/50">
                  <TableRow className="border-zinc-200 hover:bg-transparent">
                    <TableHead className="text-zinc-500 text-xs">Item Details</TableHead>
                    <TableHead className="text-zinc-500 text-xs w-[120px]">Serial No.</TableHead>
                    <TableHead className="text-zinc-500 text-xs text-right w-[100px]">Selling Price</TableHead>
                    <TableHead className="text-zinc-500 text-xs text-center w-[120px]">Qty</TableHead>
                    <TableHead className="text-zinc-500 text-xs text-right w-[100px]">Total</TableHead>
                    <TableHead className="text-zinc-500 text-xs text-center w-[50px]"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {billItems.length === 0 ? (
                    <TableRow className="hover:bg-transparent">
                      <TableCell colSpan={6} className="h-40 text-center text-zinc-500 text-sm">
                        No items added to invoice yet. Search for a product above or add a custom one.
                      </TableCell>
                    </TableRow>
                  ) : (
                    billItems.map((item, index) => (
                      <TableRow key={index} className="border-zinc-200 hover:bg-white/10">
                        <TableCell>
                          <div className="font-semibold text-zinc-800">{item.name}</div>
                          {item.brand && <div className="text-[10px] text-zinc-500">{item.brand}</div>}
                          {item.productId === 'new' && (
                            <Badge className="mt-1 bg-emerald-500/10 text-emerald-600 border border-emerald-200 text-[9px] px-1 py-0 h-4">
                              New Inline
                            </Badge>
                          )}
                        </TableCell>
                        <TableCell className="font-mono text-xs text-zinc-500">{item.sku}</TableCell>
                        <TableCell>
                          <Input
                            type="number"
                            step="0.01"
                            value={item.sellingPrice}
                            onChange={(e) => handleEditItem(index, 'sellingPrice', e.target.value)}
                            className="h-8 border-transparent hover:border-zinc-200 focus:border-indigo-400 bg-transparent text-right text-sm text-zinc-700 px-1.5"
                          />
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center justify-center gap-1.5">
                            <Button
                              type="button"
                              variant="ghost"
                              size="icon"
                              onClick={() => handleUpdateQty(index, item.qty - 1)}
                              className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500 hover:text-zinc-800"
                            >
                              <Minus className="h-3 w-3" />
                            </Button>
                            <Input
                              type="number"
                              value={item.qty}
                              onChange={(e) => handleEditItem(index, 'qty', e.target.value)}
                              className="h-8 w-12 border-transparent hover:border-zinc-200 focus:border-indigo-400 bg-transparent text-center text-sm font-semibold text-zinc-900 px-1"
                            />
                            <Button
                              type="button"
                              variant="ghost"
                              size="icon"
                              onClick={() => handleUpdateQty(index, item.qty + 1)}
                              className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500 hover:text-zinc-800"
                            >
                              <Plus className="h-3 w-3" />
                            </Button>
                          </div>
                        </TableCell>
                        <TableCell className="text-right font-semibold text-zinc-800">
                          {formatINR(item.sellingPrice * item.qty)}
                        </TableCell>
                        <TableCell className="text-center">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => handleDeleteItem(index)}
                            className="h-7 w-7 text-zinc-500 hover:text-rose-600 hover:bg-rose-500/10 rounded-md transition-colors"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </div>

            {/* Added Items List for Mobile */}
            <div className="space-y-3 md:hidden">
              {billItems.length === 0 ? (
                <div className="h-40 flex items-center justify-center text-center text-zinc-500 text-sm border border-dashed border-zinc-200 rounded-lg bg-zinc-50/50">
                  No items added to invoice yet. Search for a product above or add a custom one.
                </div>
              ) : (
                billItems.map((item, index) => (
                  <Card key={index} className="border-zinc-200 bg-white shadow-sm">
                    <CardContent className="p-4 space-y-3">
                      <div className="flex items-start justify-between gap-2">
                        <div className="flex-1">
                          <div className="font-semibold text-zinc-800 text-sm">{item.name}</div>
                          {item.brand && <div className="text-[10px] text-zinc-500 mt-0.5">{item.brand}</div>}
                          {item.productId === 'new' && (
                            <Badge className="mt-1 bg-emerald-500/10 text-emerald-600 border border-emerald-200 text-[9px] px-1 py-0 h-4">
                              New Inline
                            </Badge>
                          )}
                        </div>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDeleteItem(index)}
                          className="h-8 w-8 text-zinc-400 hover:text-rose-600 hover:bg-rose-500/10 rounded-md transition-colors border border-zinc-100 shrink-0"
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>

                      <div className="grid grid-cols-3 gap-2 text-xs border-t border-zinc-100 pt-2 items-center">
                        <div>
                          <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Serial No.</span>
                          <span className="font-mono text-zinc-650 block text-[10px] mt-0.5">{item.sku}</span>
                        </div>
                        <div>
                          <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Price</span>
                          <Input
                            type="number"
                            step="0.01"
                            value={item.sellingPrice}
                            onChange={(e) => handleEditItem(index, 'sellingPrice', e.target.value)}
                            className="h-7 mt-0.5 border-transparent hover:border-zinc-200 focus:border-indigo-400 bg-transparent text-xs text-zinc-800 px-1"
                          />
                        </div>
                        <div className="text-right">
                          <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Total</span>
                          <span className="font-bold text-zinc-950 text-sm">{formatINR(item.sellingPrice * item.qty)}</span>
                        </div>
                      </div>

                      <div className="flex justify-between items-center text-xs pt-2 border-t border-zinc-100">
                        <div className="flex items-center gap-1">
                          <span className="text-zinc-400 text-[9px] uppercase font-semibold mr-1.5">Qty:</span>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => handleUpdateQty(index, item.qty - 1)}
                            className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500"
                          >
                            <Minus className="h-3 w-3" />
                          </Button>
                          <Input
                            type="number"
                            value={item.qty}
                            onChange={(e) => handleEditItem(index, 'qty', e.target.value)}
                            className="h-7 w-10 border-transparent hover:border-zinc-200 focus:border-indigo-400 bg-transparent text-center font-bold text-zinc-900 px-0"
                          />
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => handleUpdateQty(index, item.qty + 1)}
                            className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500"
                          >
                            <Plus className="h-3 w-3" />
                          </Button>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
