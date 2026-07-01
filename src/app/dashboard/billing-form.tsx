'use client'

import { useState, useEffect, useRef, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { searchCustomers, searchProducts, createBill, updateBill } from '../actions/billing'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { Switch } from '@/components/ui/switch'
import { Plus, Minus, Trash2, Search, UserPlus, PackagePlus, Loader2, ArrowRight, ChevronDown, ChevronUp, AlertCircle } from 'lucide-react'
import { toast } from 'sonner'
import { formatINR, cn } from '@/lib/utils'

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

interface EditBillData {
  id: string
  bill_number: string
  customer_id: string
  customer_name: string
  customer_phone: string
  customer_email?: string | null
  customer_address?: string | null
  items: {
    productId: string
    name: string
    brand: string
    category: string
    sku: string
    sellingPrice: number
    mrp?: number | null
    qty: number
  }[]
  payment_status: 'paid' | 'unpaid' | 'advance' | 'partial'
  advance_amount?: number
  discount?: number
  payment_collections?: {
    id: string
    amount: number
    payment_method: 'upi' | 'bank' | 'cash' | 'card'
    payment_type: string
  }[]
}

interface BillingFormProps {
  editBill?: EditBillData | null
}

export default function BillingForm({ editBill }: BillingFormProps = {}) {
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
  const [showOptionalCustomerFields, setShowOptionalCustomerFields] = useState(false)
  const customerSearchRef = useRef<HTMLDivElement>(null)

  // Product Search State
  const [productSearch, setProductSearch] = useState('')
  const [productResults, setProductResults] = useState<Product[]>([])
  const [showProductSearch, setShowProductSearch] = useState(false)
  const productSearchRef = useRef<HTMLDivElement>(null)

  // Items added to bill
  const [billItems, setBillItems] = useState<SelectedItem[]>([])

  // Payment status
  const [paymentStatus, setPaymentStatus] = useState<'paid' | 'unpaid' | 'advance'>('paid')
  const [advanceAmount, setAdvanceAmount] = useState('')
  const [discount, setDiscount] = useState('')
  const [paymentMethod, setPaymentMethod] = useState<'upi' | 'bank' | 'cash' | 'card'>('cash')
  const [isEditMode, setIsEditMode] = useState(false)
  const [editBillId, setEditBillId] = useState<string | null>(null)

  // Split payment state
  const [isSplitPayment, setIsSplitPayment] = useState(false)
  const [splitPayments, setSplitPayments] = useState<{
    method: 'cash' | 'upi' | 'card' | 'bank'
    amount: string
  }[]>([{ method: 'cash', amount: '' }])

  // Helper to add a split payment row
  const addSplitRow = () => {
    if (splitPayments.length >= 4) {
      toast.error('You can add a maximum of 4 split payment fields.')
      return
    }
    const usedMethods = splitPayments.map(sp => sp.method)
    const allMethods: ('cash' | 'upi' | 'card' | 'bank')[] = ['cash', 'upi', 'card', 'bank']
    const available = allMethods.find(m => !usedMethods.includes(m))
    if (available) {
      setSplitPayments([...splitPayments, { method: available, amount: '' }])
    } else {
      toast.error('All payment methods have already been added.')
    }
  }

  // Helper to remove a split payment row
  const removeSplitRow = (index: number) => {
    const updated = [...splitPayments]
    updated.splice(index, 1)
    setSplitPayments(updated)
  }

  // Helper to update a split payment row's method or amount
  const updateSplitRow = (index: number, key: 'method' | 'amount', value: string) => {
    const updated = [...splitPayments]
    if (key === 'method') {
      updated[index].method = value as 'cash' | 'upi' | 'card' | 'bank'
    } else {
      updated[index].amount = value
    }
    setSplitPayments(updated)
  }

  // Helper to check if a method is already selected in another row
  const isMethodUsed = (method: 'cash' | 'upi' | 'card' | 'bank', currentIndex: number) => {
    return splitPayments.some((sp, idx) => idx !== currentIndex && sp.method === method)
  }

  // Suggestion for existing customer
  const [existingCustomerSuggestion, setExistingCustomerSuggestion] = useState<Customer | null>(null)

  useEffect(() => {
    const phone = newCustomer.phone.trim()
    if (phone.length >= 5) {
      const delayDebounce = setTimeout(async () => {
        const results = await searchCustomers(phone)
        const cleanPhone = phone.replace(/\D/g, '')
        const exactMatch = results.find(c => {
          const dbPhone = c.phone.replace(/\D/g, '')
          return dbPhone.includes(cleanPhone) || cleanPhone.includes(dbPhone)
        })
        if (exactMatch) {
          setExistingCustomerSuggestion(exactMatch)
        } else {
          setExistingCustomerSuggestion(null)
        }
      }, 300)
      return () => clearTimeout(delayDebounce)
    } else {
      setExistingCustomerSuggestion(null)
    }
  }, [newCustomer.phone])

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

  // Load edit bill data when provided
  useEffect(() => {
    if (editBill) {
      setIsEditMode(true)
      setEditBillId(editBill.id)
      setSelectedCustomer({
        id: editBill.customer_id,
        name: editBill.customer_name,
        phone: editBill.customer_phone,
        email: editBill.customer_email || undefined,
        address: editBill.customer_address || undefined
      })
      setBillItems(editBill.items.map((item) => ({
        productId: item.productId as string | 'new',
        name: item.name,
        brand: item.brand,
        category: item.category,
        sku: item.sku,
        sellingPrice: item.sellingPrice,
        mrp: item.mrp,
        qty: item.qty
      })))
      const status = editBill.payment_status === 'partial' ? 'advance' : editBill.payment_status
      setPaymentStatus(status as 'paid' | 'unpaid' | 'advance')
      if (editBill.advance_amount && editBill.advance_amount > 0) {
        setAdvanceAmount(String(editBill.advance_amount))
      }
      if (editBill.discount && editBill.discount > 0) {
        setDiscount(String(editBill.discount))
      }

      // Load split payments / payment collections if present
      if (editBill.payment_collections && editBill.payment_collections.length > 0) {
        const collections = editBill.payment_collections
        const newSplits = collections.map((c) => ({
          method: c.payment_method as 'cash' | 'upi' | 'card' | 'bank',
          amount: String(c.amount)
        }))

        setSplitPayments(newSplits)
        setIsSplitPayment(collections.length > 1)
        if (collections.length === 1) {
          setPaymentMethod(collections[0].payment_method)
        }
      } else {
        setSplitPayments([{ method: 'cash', amount: '' }])
      }
    }
  }, [editBill])

  // Select Customer
  const handleSelectCustomer = (customer: Customer) => {
    setSelectedCustomer(customer)
    setIsNewCustomer(false)
    setCustomerSearch('')
    setShowCustomerSearch(false)
    setExistingCustomerSuggestion(null)
  }

  // Clear Selected Customer
  const handleClearCustomer = () => {
    setSelectedCustomer(null)
    setIsNewCustomer(false)
    setNewCustomer({ name: '', phone: '', email: '', address: '' })
    setShowOptionalCustomerFields(false)
    setExistingCustomerSuggestion(null)
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
    let subtotal = 0

    billItems.forEach((item) => {
      subtotal += item.sellingPrice * item.qty
    })

    const discountAmount = discount ? Math.min(parseFloat(discount) || 0, subtotal) : 0
    const total = Math.max(0, subtotal - discountAmount)

    return {
      subtotal: Math.round(subtotal * 100) / 100,
      discount: Math.round(discountAmount * 100) / 100,
      total: Math.round(total * 100) / 100
    }
  }

  const totals = calculateTotals()

  // Helper to calculate total split amount
  const getSplitTotal = () => {
    return splitPayments.reduce((sum, sp) => sum + (parseFloat(sp.amount) || 0), 0)
  }

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

    let splitPaymentsPayload: { method: 'upi' | 'bank' | 'cash' | 'card'; amount: number }[] = []

    if (paymentStatus === 'paid' || paymentStatus === 'advance') {
      if (isSplitPayment) {
        // Check for duplicate payment methods in split payments
        const usedMethods = new Set()
        for (const sp of splitPayments) {
          if (usedMethods.has(sp.method)) {
            toast.error(`Duplicate payment method detected: ${sp.method.toUpperCase()}. Each method can only be used once.`)
            return
          }
          usedMethods.add(sp.method)
        }

        const splitTotal = getSplitTotal()

        if (splitTotal <= 0) {
          toast.error('Please enter at least one payment amount for split payment.')
          return
        }

        if (paymentStatus === 'paid' && Math.round(splitTotal * 100) / 100 !== Math.round(totals.total * 100) / 100) {
          toast.error(`Total split payment amount (${formatINR(splitTotal)}) must equal the grand total (${formatINR(totals.total)}).`)
          return
        }

        if (paymentStatus === 'advance') {
          if (splitTotal >= totals.total) {
            toast.error('Total advance payment cannot be greater than or equal to the total amount.')
            return
          }
        }

        // Map splitPayments array to splitPaymentsPayload
        splitPayments.forEach((sp) => {
          const amt = parseFloat(sp.amount) || 0
          if (amt > 0) {
            splitPaymentsPayload.push({
              method: sp.method,
              amount: amt
            })
          }
        })
      } else {
        if (paymentStatus === 'advance') {
          const advAmt = parseFloat(advanceAmount)
          if (isNaN(advAmt) || advAmt <= 0) {
            toast.error('Please enter a valid advance amount.')
            return
          }
          if (advAmt >= totals.total) {
            toast.error('Advance amount cannot be greater than or equal to the total amount.')
            return
          }
        }
      }
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
          paymentStatus,
          advanceAmount: paymentStatus === 'advance' 
            ? (isSplitPayment ? getSplitTotal() : parseFloat(advanceAmount)) 
            : undefined,
          discount: discount ? parseFloat(discount) : 0,
          paymentMethod: paymentStatus === 'paid' || paymentStatus === 'advance' ? (isSplitPayment ? undefined : paymentMethod) : undefined,
          splitPayments: splitPaymentsPayload.length > 0 ? splitPaymentsPayload : undefined
        }

        const res = isEditMode && editBillId
          ? await updateBill(editBillId, payload)
          : await createBill(payload)

        if (res.error) {
          toast.error(res.error)
        } else {
          toast.success(isEditMode ? 'Invoice updated successfully!' : 'Invoice created successfully!')
          router.push('/dashboard/bills')
        }
      } catch (error: unknown) {
        toast.error(error instanceof Error ? error.message : 'Failed to save bill.')
      }
    })
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Left panel: Customer details */}
      <div className="lg:col-span-1 space-y-6 order-2 lg:order-1">
        <Card className="border-zinc-200 bg-white shadow-sm overflow-visible z-10">
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
                    <div className="absolute z-50 w-full mt-1 border border-zinc-200 bg-white rounded-md shadow-lg max-h-60 overflow-y-auto">
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
                    <div className="absolute z-50 w-full mt-1 p-3 border border-zinc-200 bg-white rounded-md text-zinc-500 text-xs text-center space-y-2">
                      <div>No customer found matching "{customerSearch}"</div>
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          const isPhone = /^[\d\s+\-()]+$/.test(customerSearch.trim())
                          if (isPhone) {
                            setNewCustomer({ ...newCustomer, phone: customerSearch.trim(), name: '' })
                          } else {
                            setNewCustomer({ ...newCustomer, name: customerSearch.trim(), phone: '' })
                          }
                          setIsNewCustomer(true)
                        }}
                        className="border-indigo-200 text-indigo-600 hover:bg-indigo-50 gap-1.5"
                      >
                        <UserPlus className="h-3.5 w-3.5" />
                        Add "{customerSearch}" as New Customer
                      </Button>
                    </div>
                  )}
                </div>
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
                  <Label htmlFor="cust-phone" className="text-zinc-700 text-xs font-semibold">Phone Number *</Label>
                  <Input
                    id="cust-phone"
                    placeholder="Enter mobile number"
                    value={newCustomer.phone}
                    onChange={(e) => setNewCustomer({ ...newCustomer, phone: e.target.value })}
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600 h-11 text-base font-medium"
                    required
                    autoFocus
                  />
                  {existingCustomerSuggestion && (
                    <div className="p-2.5 rounded-md border border-indigo-200 bg-indigo-50/50 flex flex-col gap-1.5 text-xs mt-1 animate-in fade-in slide-in-from-top-1">
                      <span className="text-zinc-700 font-medium">
                        Customer with phone <strong>{existingCustomerSuggestion.phone}</strong> already exists: <strong>{existingCustomerSuggestion.name}</strong>
                      </span>
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => handleSelectCustomer(existingCustomerSuggestion)}
                        className="border-indigo-300 text-indigo-600 hover:bg-indigo-50 py-1 h-7 text-xs font-semibold self-start"
                      >
                        Use "{existingCustomerSuggestion.name}" instead
                      </Button>
                    </div>
                  )}
                </div>
                <div className="space-y-2">
                  <Label htmlFor="cust-name" className="text-zinc-700 text-xs font-semibold">Customer Name *</Label>
                  <Input
                    id="cust-name"
                    placeholder="Enter full name"
                    value={newCustomer.name}
                    onChange={(e) => setNewCustomer({ ...newCustomer, name: e.target.value })}
                    className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600 h-11 text-base font-medium"
                  />
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowOptionalCustomerFields(!showOptionalCustomerFields)}
                  className="w-full text-zinc-500 hover:text-zinc-800 gap-1 text-xs"
                >
                  {showOptionalCustomerFields ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
                  Add Email & Address (Optional)
                </Button>
                {showOptionalCustomerFields && (
                  <div className="space-y-3 pt-1 border-t border-zinc-100">
                    <div className="space-y-2">
                      <Label htmlFor="cust-email" className="text-zinc-400 text-xs">Email (Optional)</Label>
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
                      <Label htmlFor="cust-addr" className="text-zinc-400 text-xs">Address (Optional)</Label>
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
              </div>
            )}
          </CardContent>
        </Card>

        {/* Totals and Submit */}
        <Card className="border-zinc-200 bg-white shadow-sm">
          <CardContent className="pt-6 space-y-4">
            <div className="space-y-2">
              <Label className="text-zinc-700 text-xs">Payment Status</Label>
              <Select value={paymentStatus} onValueChange={(val) => val && setPaymentStatus(val as 'paid' | 'unpaid' | 'advance')}>
                <SelectTrigger className="border-zinc-200 bg-white text-zinc-900 focus:ring-indigo-500">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="bg-white border-zinc-200 text-zinc-900">
                  <SelectItem value="paid">Paid</SelectItem>
                  <SelectItem value="unpaid">Unpaid</SelectItem>
                  <SelectItem value="advance">Advance</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {(paymentStatus === 'paid' || paymentStatus === 'advance') && (
              <div className="space-y-4 border-t border-zinc-100 pt-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="split-payment-toggle" className="text-zinc-700 text-xs font-semibold cursor-pointer">
                    Split Payment Mode
                  </Label>
                  <Switch
                    id="split-payment-toggle"
                    checked={isSplitPayment}
                    onCheckedChange={setIsSplitPayment}
                  />
                </div>

                {!isSplitPayment ? (
                  <div className="space-y-2">
                    <Label className="text-zinc-700 text-xs">Payment Method</Label>
                    <Select value={paymentMethod} onValueChange={(val) => val && setPaymentMethod(val as 'upi' | 'bank' | 'cash' | 'card')}>
                      <SelectTrigger className="border-zinc-200 bg-white text-zinc-900 focus:ring-indigo-500">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent className="bg-white border-zinc-200 text-zinc-900">
                        <SelectItem value="cash">Cash</SelectItem>
                        <SelectItem value="upi">UPI</SelectItem>
                        <SelectItem value="card">Card</SelectItem>
                        <SelectItem value="bank">Bank Transfer</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                ) : (
                  <div className="space-y-3 p-3 bg-zinc-50 rounded-lg border border-zinc-200">
                    <span className="text-xs font-bold text-zinc-700 block mb-1">Enter amounts for payment methods:</span>
                    <div className="space-y-2">
                      {splitPayments.map((sp, idx) => (
                        <div key={idx} className="flex gap-2 items-center">
                          <Select
                            value={sp.method}
                            onValueChange={(val) => val && updateSplitRow(idx, 'method', val)}
                          >
                            <SelectTrigger className="w-[120px] h-9 border-zinc-200 bg-white text-zinc-900 focus:ring-indigo-500 text-xs">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent className="bg-white border-zinc-200 text-zinc-900 text-xs">
                              <SelectItem value="cash" disabled={isMethodUsed('cash', idx)}>Cash</SelectItem>
                              <SelectItem value="upi" disabled={isMethodUsed('upi', idx)}>UPI</SelectItem>
                              <SelectItem value="card" disabled={isMethodUsed('card', idx)}>Card</SelectItem>
                              <SelectItem value="bank" disabled={isMethodUsed('bank', idx)}>Bank Transfer</SelectItem>
                            </SelectContent>
                          </Select>
                          <Input
                            type="number"
                            placeholder="Amount"
                            value={sp.amount}
                            onChange={(e) => updateSplitRow(idx, 'amount', e.target.value)}
                            className="h-9 border-zinc-200 bg-white text-zinc-900 focus-visible:ring-indigo-600 text-xs flex-1"
                          />
                          {splitPayments.length > 1 && (
                            <Button
                              type="button"
                              variant="ghost"
                              size="icon"
                              onClick={() => removeSplitRow(idx)}
                              className="h-9 w-9 text-rose-500 hover:text-rose-600 hover:bg-rose-50"
                            >
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          )}
                        </div>
                      ))}
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={addSplitRow}
                      disabled={splitPayments.length >= 4}
                      className="w-full h-8 mt-1 border-dashed border-zinc-300 text-zinc-600 hover:text-zinc-800 hover:bg-zinc-100 flex items-center justify-center gap-1 text-xs disabled:opacity-50"
                    >
                      <Plus className="h-3.5 w-3.5" />
                      Add Payment Method
                    </Button>
                    <div className="text-xs pt-1.5 border-t border-zinc-200/50 flex justify-between items-center">
                      <span className="text-zinc-500">Total Entered:</span>
                      <span className={cn(
                        "font-bold",
                        paymentStatus === 'paid'
                          ? Math.round(getSplitTotal() * 100) / 100 === Math.round(totals.total * 100) / 100
                            ? "text-emerald-600"
                            : "text-rose-600"
                          : "text-indigo-600"
                      )}>
                        {formatINR(getSplitTotal())}
                        {paymentStatus === 'paid' && ` / ${formatINR(totals.total)}`}
                      </span>
                    </div>
                    {paymentStatus === 'paid' && Math.round(getSplitTotal() * 100) / 100 !== Math.round(totals.total * 100) / 100 && (
                      <div className={cn(
                        "mt-2 p-2 rounded text-xs font-semibold flex items-center gap-1.5 border",
                        getSplitTotal() < totals.total
                          ? "bg-amber-50 border-amber-200 text-amber-700"
                          : "bg-rose-50 border-rose-200 text-rose-700"
                      )}>
                        <AlertCircle className="h-3.5 w-3.5 flex-shrink-0" />
                        <span>
                          {getSplitTotal() < totals.total
                            ? `Remaining: ${formatINR(totals.total - getSplitTotal())} to be added.`
                            : `Excess: ${formatINR(getSplitTotal() - totals.total)} to be removed.`}
                        </span>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}

            {paymentStatus === 'advance' && !isSplitPayment && (
              <div className="space-y-2">
                <Label htmlFor="advance-amount" className="text-zinc-700 text-xs font-semibold">Advance Amount</Label>
                <Input
                  id="advance-amount"
                  type="number"
                  step="0.01"
                  placeholder="Enter advance amount"
                  value={advanceAmount}
                  onChange={(e) => setAdvanceAmount(e.target.value)}
                  className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                />
                {advanceAmount && !isNaN(parseFloat(advanceAmount)) && parseFloat(advanceAmount) < totals.total && (
                  <div className="flex justify-between text-xs text-zinc-500 bg-amber-50 border border-amber-200 rounded-md px-3 py-2">
                    <span>Remaining Due:</span>
                    <span className="font-semibold text-amber-700">{formatINR(totals.total - parseFloat(advanceAmount))}</span>
                  </div>
                )}
              </div>
            )}

            <div className="space-y-2">
              <Label htmlFor="discount-amount" className="text-zinc-700 text-xs font-semibold">Flat Discount (Optional)</Label>
              <Input
                id="discount-amount"
                type="number"
                step="0.01"
                placeholder="Enter flat discount amount"
                value={discount}
                onChange={(e) => setDiscount(e.target.value)}
                onWheel={(e) => e.currentTarget.blur()}
                className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
              />
            </div>

            <div className="border-t border-zinc-200 pt-4 space-y-2">
              <div className="flex justify-between text-sm text-zinc-600">
                <span>Subtotal:</span>
                <span>{formatINR(totals.subtotal)}</span>
              </div>
              {totals.discount > 0 && (
                <div className="flex justify-between text-sm text-rose-600">
                  <span>Discount:</span>
                  <span>- {formatINR(totals.discount)}</span>
                </div>
              )}
              {paymentStatus === 'advance' && (isSplitPayment ? getSplitTotal() > 0 : (advanceAmount && !isNaN(parseFloat(advanceAmount)))) && (isSplitPayment ? getSplitTotal() : parseFloat(advanceAmount)) < totals.total && (
                <div className="flex justify-between text-sm text-zinc-600">
                  <span>Advance Paid:</span>
                  <span>{formatINR(isSplitPayment ? getSplitTotal() : parseFloat(advanceAmount))}</span>
                </div>
              )}
              {paymentStatus === 'advance' && (isSplitPayment ? getSplitTotal() > 0 : (advanceAmount && !isNaN(parseFloat(advanceAmount)))) && (isSplitPayment ? getSplitTotal() : parseFloat(advanceAmount)) < totals.total && (
                <div className="flex justify-between text-sm font-semibold text-amber-700">
                  <span>Due Amount:</span>
                  <span>{formatINR(totals.total - (isSplitPayment ? getSplitTotal() : parseFloat(advanceAmount)))}</span>
                </div>
              )}
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
                  {isEditMode ? 'Updating Invoice...' : 'Generating Invoice...'}
                </>
              ) : (
                <>
                  {isEditMode ? 'Update Bill' : 'Generate Bill & Print'}
                  <ArrowRight className="h-4 w-4" />
                </>
              )}
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Right panel: Search and Items table */}
      <div className="lg:col-span-2 space-y-6 order-1 lg:order-2">
        <Card className="border-zinc-200 bg-white shadow-sm overflow-visible z-10">
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
                <div className="absolute z-50 w-full mt-1 border border-zinc-200 bg-white rounded-md shadow-lg max-h-60 overflow-y-auto">
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
                <div className="absolute z-50 w-full mt-1 p-4 border border-zinc-200 bg-white rounded-md text-zinc-500 text-xs text-center flex flex-col items-center gap-2">
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
                          <div className="font-semibold text-zinc-800 truncate max-w-[180px]" title={item.name}>{item.name.length > 10 ? item.name.slice(0, 10) + '...' : item.name}</div>
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
                          <div className="font-semibold text-zinc-800 text-sm truncate" title={item.name}>{item.name.length > 10 ? item.name.slice(0, 10) + '...' : item.name}</div>
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
