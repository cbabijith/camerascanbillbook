'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { Card, CardContent } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { Search, Eye, Share2, Printer, Loader2, Wallet, Pencil, Trash2 } from 'lucide-react'
import { format } from 'date-fns'
import { formatINR } from '@/lib/utils'
import { toast } from 'sonner'
import { Label } from '@/components/ui/label'
import Link from 'next/link'
import { generateInvoiceFile, generateInvoiceBlob, downloadInvoicePDF, printInvoicePDF } from '@/lib/pdf-generator'
import { createClient } from '@/lib/supabase/client'
import { collectPayment, deleteBill } from '@/app/actions/billing'

interface BillItem {
  productId: string
  name: string
  brand: string
  category: string
  sku: string
  sellingPrice: number
  mrp?: number | null
  qty: number
  basePrice: number
  total: number
}

interface PaymentCollection {
  id: string
  bill_id: string
  amount: number
  payment_type: 'advance' | 'partial' | 'final'
  payment_method: 'upi' | 'bank' | 'cash' | 'card'
  collected_by: string | null
  collected_at: string
  profiles?: {
    name: string
  }
}

interface Bill {
  id: string
  bill_number: string
  customer_name: string
  customer_phone: string
  sub_total: number
  gst_amount: number
  total: number
  advance_amount?: number
  discount?: number
  payment_status: 'paid' | 'unpaid' | 'advance' | 'partial'
  created_at: string
  items: BillItem[]
  profiles?: {
    name: string
  }
  payment_collections?: PaymentCollection[]
}

interface BillsListProps {
  initialBills: Bill[]
  activeBranch: {
    name: string
    address?: string
    phone?: string
    gstin?: string
  } | null
  userRole?: string | null
}

export default function BillsList({ initialBills, activeBranch, userRole }: BillsListProps) {
  const router = useRouter()
  const isAdmin = userRole === 'admin'
  const [search, setSearch] = useState('')
  const [selectedBill, setSelectedBill] = useState<Bill | null>(null)
  const [isReceiptOpen, setIsReceiptOpen] = useState(false)
  const [sharingBillId, setSharingBillId] = useState<string | null>(null)
  const [collectBill, setCollectBill] = useState<Bill | null>(null)
  const [collectAmount, setCollectAmount] = useState('')
  const [collectPaymentMethod, setCollectPaymentMethod] = useState<'upi' | 'bank' | 'cash' | 'card'>('cash')
  const [isCollecting, setIsCollecting] = useState(false)
  const [deleteBillTarget, setDeleteBillTarget] = useState<Bill | null>(null)
  const [isDeleting, setIsDeleting] = useState(false)
  const [visibleCount, setVisibleCount] = useState(15)
  const sentinelRef = useRef<HTMLDivElement>(null)

  // Filter bills based on search query
  const filteredBills = initialBills.filter((bill) => {
    const term = search.toLowerCase()
    return (
      bill.bill_number.toLowerCase().includes(term) ||
      bill.customer_name.toLowerCase().includes(term) ||
      bill.customer_phone.includes(term)
    )
  })

  // Reset visible count when search changes
  useEffect(() => {
    setVisibleCount(15)
  }, [search])

  // Infinite scroll for mobile view
  const handleIntersect = useCallback((entries: IntersectionObserverEntry[]) => {
    if (entries[0].isIntersecting && visibleCount < filteredBills.length) {
      setVisibleCount((prev) => prev + 15)
    }
  }, [visibleCount, filteredBills.length])

  useEffect(() => {
    const sentinel = sentinelRef.current
    if (!sentinel) return
    const observer = new IntersectionObserver(handleIntersect, { threshold: 0.1 })
    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [handleIntersect])

  // Open Receipt
  const handleOpenReceipt = (bill: Bill) => {
    setSelectedBill(bill)
    setIsReceiptOpen(true)
  }

  // Direct print from table — generates PDF and triggers print dialog
  const handleDirectPrint = (bill: Bill) => {
    printInvoicePDF(bill, activeBranch)
  }

  // Build the WhatsApp text summary for a bill
  const buildWhatsAppText = (bill: Bill, pdfUrl?: string) => {
    const formattedDate = format(new Date(bill.created_at), 'dd-MMM-yyyy')
    let text = `*INVOICE: ${bill.bill_number}*\n`
    text += `Date: ${formattedDate}\n`
    text += `Store: ${activeBranch?.name || 'Camera Shop'}\n`
    text += `Customer: ${bill.customer_name} (${bill.customer_phone})\n`
    text += `=========================\n`

    bill.items.forEach((item) => {
      text += `- ${item.name} (${item.qty} x ${formatINR(item.sellingPrice)}) = ${formatINR(item.total)}\n`
    })

    text += `=========================\n`
    text += `Subtotal: ${formatINR(bill.sub_total)}\n`
    text += `*Grand Total: ${formatINR(bill.total)}*\n`
    text += `Payment Status: *${bill.payment_status.toUpperCase()}*\n\n`

    if (pdfUrl) {
      text += `📄 Download Invoice PDF:\n${pdfUrl}\n\n`
    }

    text += `Thank you for shopping with us!`
    return text
  }

  // Open WhatsApp with text (and optional PDF link)
  const openWhatsApp = (bill: Bill, pdfUrl?: string) => {
    const text = buildWhatsAppText(bill, pdfUrl)
    const encodedText = encodeURIComponent(text)
    const cleanPhone = bill.customer_phone.replace(/\D/g, '')
    const url = `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodedText}`
    window.open(url, '_blank')
  }

  // Handle WhatsApp Share with PDF
  const handleWhatsAppShare = async (bill: Bill) => {
    setSharingBillId(bill.id)
    try {
      // Step 1: Generate the PDF file
      const pdfFile = generateInvoiceFile(bill, activeBranch)

      // Step 2: Try native share (works well on mobile)
      if (typeof navigator !== 'undefined' && navigator.share && navigator.canShare?.({ files: [pdfFile] })) {
        try {
          await navigator.share({
            title: `Invoice ${bill.bill_number}`,
            text: buildWhatsAppText(bill),
            files: [pdfFile]
          })
          toast.success('Invoice shared successfully!')
          setSharingBillId(null)
          return
        } catch (shareErr: unknown) {
          // User cancelled or share failed – fall through to upload approach
          if (shareErr instanceof DOMException && shareErr.name === 'AbortError') {
            setSharingBillId(null)
            return
          }
        }
      }

      // Step 3: Upload to Supabase Storage and get a public URL
      try {
        const supabase = createClient()
        const pdfBlob = generateInvoiceBlob(bill, activeBranch)
        const filePath = `${bill.bill_number}.pdf`

        const { error: uploadError } = await supabase.storage
          .from('invoices')
          .upload(filePath, pdfBlob, {
            contentType: 'application/pdf',
            upsert: true
          })

        if (!uploadError) {
          const { data: urlData } = supabase.storage
            .from('invoices')
            .getPublicUrl(filePath)

          if (urlData?.publicUrl) {
            openWhatsApp(bill, urlData.publicUrl)
            toast.success('Invoice PDF link sent to WhatsApp!')
            setSharingBillId(null)
            return
          }
        }
        // If upload failed, fall through to download fallback
        console.warn('Supabase upload failed, falling back to download:', uploadError)
      } catch (storageErr) {
        console.warn('Supabase storage not available, falling back to download:', storageErr)
      }

      // Step 4: Fallback – download PDF locally and open WhatsApp with text only
      downloadInvoicePDF(bill, activeBranch)
      toast.info('PDF downloaded! Attach it manually in WhatsApp.')
      openWhatsApp(bill)
    } catch (err) {
      console.error('Failed to share invoice:', err)
      toast.error('Failed to generate invoice PDF.')
    } finally {
      setSharingBillId(null)
    }
  }

  // Handle deleting a bill
  const handleDeleteBill = async () => {
    if (!deleteBillTarget) return
    setIsDeleting(true)
    try {
      const res = await deleteBill(deleteBillTarget.id)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success('Invoice deleted successfully.')
        setDeleteBillTarget(null)
        router.refresh()
      }
    } catch {
      toast.error('Failed to delete invoice.')
    } finally {
      setIsDeleting(false)
    }
  }

  // Handle print — generates PDF and triggers print dialog
  const handlePrint = () => {
    if (selectedBill) {
      printInvoicePDF(selectedBill, activeBranch)
    }
  }

  // Get due amount for a bill
  const getDueAmount = (bill: Bill) => {
    const paid = bill.advance_amount || 0
    return Math.max(0, bill.total - paid)
  }

  // Handle collecting remaining payment
  const handleCollectPayment = async () => {
    if (!collectBill) return
    const amt = parseFloat(collectAmount)
    if (isNaN(amt) || amt <= 0) {
      toast.error('Please enter a valid amount.')
      return
    }
    const due = getDueAmount(collectBill)
    if (amt > due) {
      toast.error(`Amount exceeds due amount of ${formatINR(due)}`)
      return
    }

    setIsCollecting(true)
    try {
      const res = await collectPayment(collectBill.id, amt, collectPaymentMethod)
      if (res.error) {
        toast.error(res.error)
      } else {
        toast.success(`Payment collected successfully! Status: ${res.newStatus}`)
        setCollectBill(null)
        setCollectAmount('')
        setCollectPaymentMethod('cash')
        router.refresh()
      }
    } catch {
      toast.error('Failed to collect payment.')
    } finally {
      setIsCollecting(false)
    }
  }

  return (
    <div className="space-y-4">
      {/* Search Filter bar */}
      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-500" />
        <Input
          placeholder="Search by Bill #, Customer, or Phone..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="pl-9 border-zinc-200 bg-zinc-100 text-zinc-900 focus-visible:ring-indigo-600"
        />
      </div>

      {/* Bills table card */}
      <Card className="border-zinc-200 bg-white shadow-sm overflow-hidden hidden md:block">
        <CardContent className="p-0">
          <Table>
            <TableHeader className="bg-zinc-100/50">
              <TableRow className="border-zinc-200 hover:bg-transparent">
                <TableHead className="text-zinc-500 text-xs">Bill Number</TableHead>
                <TableHead className="text-zinc-500 text-xs">Customer Name</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[120px]">Phone</TableHead>
                <TableHead className="text-zinc-500 text-xs text-right w-[110px]">Total Amount</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[120px]">Bill Date</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[110px]">Status</TableHead>
                <TableHead className="text-zinc-500 text-xs w-[120px]">Created By</TableHead>
                <TableHead className="text-zinc-500 text-xs text-center w-[120px]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredBills.length === 0 ? (
                <TableRow className="hover:bg-transparent">
                  <TableCell colSpan={8} className="h-40 text-center text-zinc-500 text-sm">
                    No invoices found.
                  </TableCell>
                </TableRow>
              ) : (
                filteredBills.map((bill) => (
                  <TableRow key={bill.id} className="border-zinc-200 hover:bg-white/10">
                    <TableCell className="font-semibold text-zinc-800">{bill.bill_number}</TableCell>
                    <TableCell className="text-zinc-800 font-medium">{bill.customer_name}</TableCell>
                    <TableCell className="text-zinc-500 font-mono text-xs">{bill.customer_phone}</TableCell>
                    <TableCell className="text-right font-semibold text-indigo-600">{formatINR(bill.total)}</TableCell>
                    <TableCell className="text-zinc-500 text-xs">
                      {format(new Date(bill.created_at), 'dd-MMM-yyyy hh:mm a')}
                    </TableCell>
                    <TableCell>
                      <Badge
                        className={
                          bill.payment_status === 'paid'
                            ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-200'
                            : bill.payment_status === 'advance' || bill.payment_status === 'partial'
                            ? 'bg-amber-500/10 text-amber-600 border border-amber-200'
                            : 'bg-rose-500/10 text-rose-600 border border-rose-200'
                        }
                      >
                        {bill.payment_status}
                        {bill.payment_status !== 'paid' && bill.advance_amount ? ` (${formatINR(getDueAmount(bill))} due)` : ''}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-zinc-500 text-xs">{bill.profiles?.name || 'Unknown'}</TableCell>
                    <TableCell>
                      <div className="flex items-center justify-center gap-1.5">
                        {bill.payment_status !== 'paid' && (
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => {
                              setCollectBill(bill)
                              setCollectAmount('')
                            }}
                            className="h-7 w-7 border border-zinc-200 hover:bg-white text-emerald-600 hover:text-emerald-500 hover:bg-emerald-500/10"
                            title="Collect Payment"
                          >
                            <Wallet className="h-3.5 w-3.5" />
                          </Button>
                        )}
                        <Link href={`/dashboard/bills/${bill.id}/edit`} prefetch={true}>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="h-7 w-7 border border-zinc-200 hover:bg-white text-indigo-600 hover:text-indigo-500 hover:bg-indigo-500/10"
                            title="Edit Bill"
                          >
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                        </Link>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleOpenReceipt(bill)}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-zinc-500 hover:text-zinc-800"
                          title="View Invoice"
                        >
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDirectPrint(bill)}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-indigo-600 hover:text-indigo-500 hover:bg-indigo-500/10"
                          title="Print Receipt"
                        >
                          <Printer className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleWhatsAppShare(bill)}
                          disabled={sharingBillId === bill.id}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-teal-600 hover:text-teal-500 hover:bg-teal-500/10"
                          title="Share on WhatsApp"
                        >
                          {sharingBillId === bill.id ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : (
                            <Share2 className="h-3.5 w-3.5" />
                          )}
                        </Button>
                        {isAdmin && (
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => setDeleteBillTarget(bill)}
                          className="h-7 w-7 border border-zinc-200 hover:bg-white text-rose-600 hover:text-rose-500 hover:bg-rose-500/10"
                          title="Delete Invoice"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                        )}
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
        {filteredBills.length === 0 ? (
          <div className="p-8 text-center text-zinc-500 border border-dashed border-zinc-200 rounded-lg bg-white">
            No invoices found.
          </div>
        ) : (
          <>
          {filteredBills.slice(0, visibleCount).map((bill) => (
            <Card key={bill.id} className="border-zinc-200 bg-white shadow-sm">
              <CardContent className="p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-zinc-800 text-sm">{bill.bill_number}</span>
                  <Badge
                    className={
                      bill.payment_status === 'paid'
                        ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-200 text-[10px]'
                        : bill.payment_status === 'advance' || bill.payment_status === 'partial'
                        ? 'bg-amber-500/10 text-amber-600 border border-amber-200 text-[10px]'
                        : 'bg-rose-500/10 text-rose-600 border border-rose-200 text-[10px]'
                    }
                  >
                    {bill.payment_status}
                  </Badge>
                </div>

                <div className="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Customer</span>
                    <span className="text-zinc-800 font-medium">{bill.customer_name}</span>
                    <span className="text-zinc-500 font-mono block text-[10px] mt-0.5">{bill.customer_phone}</span>
                  </div>
                  <div className="text-right">
                    <span className="text-zinc-400 block text-[9px] uppercase font-semibold">Total Amount</span>
                    <span className="font-bold text-indigo-600 text-sm">{formatINR(bill.total)}</span>
                  </div>
                </div>

                <div className="flex justify-between items-center text-[10px] text-zinc-400 pt-2 border-t border-zinc-100">
                  <div>
                    <span>{format(new Date(bill.created_at), 'dd-MMM-yyyy hh:mm a')}</span>
                    <span className="mx-1.5">•</span>
                    <span>By: {bill.profiles?.name || 'Unknown'}</span>
                  </div>
                  
                  <div className="flex items-center gap-1.5">
                    {bill.payment_status !== 'paid' && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => {
                          setCollectBill(bill)
                          setCollectAmount('')
                        }}
                        className="h-8 w-8 border border-zinc-200 hover:bg-white text-emerald-600"
                        title="Collect Payment"
                      >
                        <Wallet className="h-4 w-4" />
                      </Button>
                    )}
                    <Link href={`/dashboard/bills/${bill.id}/edit`} prefetch={true}>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 border border-zinc-200 hover:bg-white text-indigo-600"
                        title="Edit Bill"
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                    </Link>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleOpenReceipt(bill)}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-zinc-500"
                    >
                      <Eye className="h-4 w-4" />
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDirectPrint(bill)}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-indigo-600"
                    >
                      <Printer className="h-4 w-4" />
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleWhatsAppShare(bill)}
                      disabled={sharingBillId === bill.id}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-teal-600"
                    >
                      {sharingBillId === bill.id ? (
                        <Loader2 className="h-4 w-4 animate-spin" />
                      ) : (
                        <Share2 className="h-4 w-4" />
                      )}
                    </Button>
                    {isAdmin && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => setDeleteBillTarget(bill)}
                      className="h-8 w-8 border border-zinc-200 hover:bg-white text-rose-600"
                      title="Delete Invoice"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
          }
          {visibleCount < filteredBills.length && (
            <div ref={sentinelRef} className="flex justify-center py-4">
              <Loader2 className="h-5 w-5 animate-spin text-zinc-400" />
            </div>
          )}
          </>
        )}
      </div>

      {/* Detailed Printable Receipt Dialog */}
      <Dialog open={isReceiptOpen} onOpenChange={setIsReceiptOpen}>
        <DialogContent className="bg-white border-zinc-200 text-zinc-900 w-[95vw] sm:max-w-4xl lg:max-w-5xl xl:max-w-6xl max-h-[95vh] overflow-y-auto print:max-w-none print:bg-white print:text-black print:border-none print:shadow-none print:p-0">
          {selectedBill && (
            <>
              {/* Receipt Structure wrapper with print classes */}
              <div id="invoice-print-area" className="p-4 space-y-6 print:p-2 print:space-y-4">
                {/* Invoice Header */}
                <div className="flex flex-col sm:flex-row justify-between border-b border-zinc-200 pb-6 print:flex-row print:justify-between print:pb-3 print:border-zinc-300">
                  <div>
                    <h2 className="text-2xl font-bold tracking-tight text-zinc-900 print:text-black print:text-lg">{activeBranch?.name || 'Camera Shop'}</h2>
                    {activeBranch?.address && <p className="text-xs text-zinc-500 mt-1 print:text-black">{activeBranch.address}</p>}
                    {activeBranch?.phone && <p className="text-xs text-zinc-500 print:text-black">Phone: {activeBranch.phone}</p>}
                    {activeBranch?.gstin && <p className="text-xs text-zinc-500 font-mono mt-1 print:text-black">GSTIN: {activeBranch.gstin}</p>}
                  </div>
                  <div className="mt-4 sm:mt-0 text-left sm:text-right">
                    <span className="text-xs uppercase font-semibold text-indigo-600 tracking-wider print:text-black">Invoice</span>
                    <h3 className="text-lg font-bold text-zinc-800 print:text-black print:text-base">{selectedBill.bill_number}</h3>
                    <p className="text-xs text-zinc-500 print:text-black">Date: {format(new Date(selectedBill.created_at), 'dd-MMM-yyyy')}</p>
                    <p className="text-xs text-zinc-500 print:text-black">Time: {format(new Date(selectedBill.created_at), 'hh:mm a')}</p>
                  </div>
                </div>

                {/* Customer Info */}
                <div className="p-4 rounded-lg bg-zinc-50 border border-zinc-200 grid grid-cols-2 gap-4 print:flex print:flex-row print:justify-between print:py-2.5 print:px-0 print:border-b print:border-zinc-300 print:rounded-none">
                  <div>
                    <span className="text-[10px] uppercase font-bold text-zinc-500 tracking-wider print:text-black">Billed To:</span>
                    <h4 className="font-bold text-zinc-800 text-base print:text-black">{selectedBill.customer_name}</h4>
                    <p className="text-xs text-zinc-500 print:text-black">Phone: {selectedBill.customer_phone}</p>
                  </div>
                  <div className="text-right">
                    <span className="text-[10px] uppercase font-bold text-zinc-500 tracking-wider print:text-black">Payment:</span>
                    <div>
                      <Badge
                        className={
                          selectedBill.payment_status === 'paid'
                            ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-200 mt-1 print:text-black print:bg-transparent print:border-none print:p-0 print:font-semibold'
                            : selectedBill.payment_status === 'advance' || selectedBill.payment_status === 'partial'
                            ? 'bg-amber-500/10 text-amber-600 border border-amber-200 mt-1 print:text-black print:bg-transparent print:border-none print:p-0 print:font-semibold'
                            : 'bg-rose-500/10 text-rose-600 border border-rose-200 mt-1 print:text-black print:bg-transparent print:border-none print:p-0 print:font-semibold'
                        }
                      >
                        {selectedBill.payment_status.toUpperCase()}
                      </Badge>
                    </div>
                  </div>
                </div>

                {/* Items Table */}
                <div className="border border-zinc-200 rounded-md overflow-hidden print:border-zinc-300 print:rounded-none print:break-inside-avoid">
                  <Table>
                    <TableHeader className="bg-zinc-100 print:bg-zinc-100">
                      <TableRow className="border-zinc-200 hover:bg-transparent print:border-zinc-300">
                        <TableHead className="text-zinc-500 text-xs font-semibold print:text-black">Item Description</TableHead>
                        <TableHead className="text-zinc-500 text-xs font-semibold text-right w-[80px] print:text-black">Price</TableHead>
                        <TableHead className="text-zinc-500 text-xs font-semibold text-center w-[60px] print:text-black">Qty</TableHead>
                        <TableHead className="text-zinc-500 text-xs font-semibold text-right w-[90px] print:text-black">Total</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {selectedBill.items.map((item, index) => (
                        <TableRow key={index} className="border-zinc-200 hover:bg-transparent print:border-zinc-300">
                          <TableCell>
                            <div className="font-semibold text-zinc-800 print:text-black">{item.name}</div>
                            {item.brand && <div className="text-[9px] text-zinc-500 print:text-black">{item.brand}</div>}
                          </TableCell>
                          <TableCell className="text-right text-zinc-500 print:text-black">{formatINR(item.sellingPrice)}</TableCell>
                          <TableCell className="text-center text-zinc-700 print:text-black">{item.qty}</TableCell>
                          <TableCell className="text-right font-semibold text-zinc-800 print:text-black">{formatINR(item.total)}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>

                {/* Totals */}
                <div className="flex flex-col sm:flex-row justify-between gap-4 pt-4 border-t border-zinc-200 print:flex-row print:justify-between print:gap-8 print:pt-3 print:border-zinc-300 print:break-inside-avoid">
                  <div className="flex-1" />

                  {/* Calculations */}
                  <div className="w-full sm:w-[220px] space-y-1.5 text-sm print:space-y-1">
                    {selectedBill.discount && selectedBill.discount > 0 && (
                      <>
                        <div className="flex justify-between text-zinc-600 print:text-black">
                          <span>Subtotal:</span>
                          <span className="font-mono">{formatINR(selectedBill.sub_total)}</span>
                        </div>
                        <div className="flex justify-between text-rose-600 print:text-black">
                          <span>Discount:</span>
                          <span className="font-mono">- {formatINR(selectedBill.discount)}</span>
                        </div>
                      </>
                    )}
                    {selectedBill.payment_status !== 'paid' && selectedBill.advance_amount && selectedBill.advance_amount > 0 && (
                      <>
                        <div className="flex justify-between text-zinc-600 print:text-black">
                          <span>Advance Paid:</span>
                          <span className="font-mono">{formatINR(selectedBill.advance_amount)}</span>
                        </div>
                        <div className="flex justify-between font-semibold text-amber-700 print:text-black">
                          <span>Due Amount:</span>
                          <span className="font-mono">{formatINR(getDueAmount(selectedBill))}</span>
                        </div>
                      </>
                    )}
                    <div className="flex justify-between font-bold text-zinc-900 border-t border-zinc-200 pt-2 text-base print:text-black print:border-zinc-300">
                      <span>Grand Total:</span>
                      <span className="font-mono text-indigo-600 print:text-black">{formatINR(selectedBill.total)}</span>
                    </div>
                  </div>
                </div>

                {/* Payment History */}
                {selectedBill.payment_collections && selectedBill.payment_collections.length > 0 && (
                  <div className="border border-zinc-200 rounded-lg p-4 print:border-zinc-300 print:break-inside-avoid">
                    <h4 className="text-xs uppercase font-bold text-zinc-500 tracking-wider mb-3 print:text-black">Payment History</h4>
                    <div className="space-y-2.5">
                      {selectedBill.payment_collections.map((pc, idx) => (
                        <div key={pc.id} className="flex items-start gap-3">
                          <div className="flex flex-col items-center pt-0.5">
                            <div className={`h-2.5 w-2.5 rounded-full ${idx === 0 ? 'bg-indigo-500' : 'bg-zinc-300'}`} />
                            {idx < selectedBill.payment_collections!.length - 1 && (
                              <div className="w-px h-full bg-zinc-200 mt-1" />
                            )}
                          </div>
                          <div className="flex-1 flex justify-between items-start pb-2">
                            <div>
                              <div className="text-sm font-medium text-zinc-800 print:text-black">
                                {formatINR(pc.amount)}
                                <Badge
                                  className={`ml-2 text-[9px] ${
                                    pc.payment_type === 'final'
                                      ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-200'
                                      : pc.payment_type === 'advance'
                                      ? 'bg-indigo-500/10 text-indigo-600 border border-indigo-200'
                                      : 'bg-amber-500/10 text-amber-600 border border-amber-200'
                                  }`}
                                >
                                  {pc.payment_type}
                                </Badge>
                                <Badge className="ml-1 text-[9px] bg-zinc-100 text-zinc-600 border border-zinc-200 uppercase">
                                  {pc.payment_method}
                                </Badge>
                              </div>
                              <div className="text-[10px] text-zinc-400 mt-0.5">
                                {format(new Date(pc.collected_at), 'dd-MMM-yyyy hh:mm a')}
                                {pc.profiles?.name && ` • By: ${pc.profiles.name}`}
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Footer terms */}
                <div className="text-center text-[10px] text-zinc-500 border-t border-zinc-200 pt-4 print:text-black print:border-zinc-300 print:pt-3">
                  <p>Invoiced generated by {selectedBill.profiles?.name || 'staff member'}.</p>
                  <p className="mt-1">Computer Generated Invoice. No Signature Required.</p>
                </div>
              </div>

              {/* Actions */}
              <DialogFooter className="border-t border-zinc-200 pt-4 flex gap-2 sm:gap-0 print:hidden">
                <Button
                  type="button"
                  variant="outline"
                  onClick={handlePrint}
                  className="border-zinc-200 text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900 gap-1.5"
                >
                  <Printer className="h-4 w-4" />
                  Print Receipt
                </Button>
                <Button
                  type="button"
                  onClick={() => handleWhatsAppShare(selectedBill)}
                  disabled={sharingBillId === selectedBill.id}
                  className="bg-emerald-600 hover:bg-emerald-500 text-white gap-1.5"
                >
                  {sharingBillId === selectedBill.id ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Share2 className="h-4 w-4" />
                  )}
                  {sharingBillId === selectedBill.id ? 'Generating PDF...' : 'Share on WhatsApp'}
                </Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>

      {/* Collect Payment Dialog */}
      <Dialog open={!!collectBill} onOpenChange={(open) => !open && setCollectBill(null)}>
        <DialogContent className="bg-white border-zinc-200 text-zinc-900 sm:max-w-[400px]">
          <DialogHeader>
            <DialogTitle>Collect Payment</DialogTitle>
            <DialogDescription className="text-zinc-500">
              {collectBill && `Invoice ${collectBill.bill_number} - ${collectBill.customer_name}`}
            </DialogDescription>
          </DialogHeader>
          {collectBill && (
            <div className="space-y-4 py-2">
              <div className="space-y-1.5 text-sm">
                <div className="flex justify-between text-zinc-600">
                  <span>Total Amount:</span>
                  <span className="font-semibold">{formatINR(collectBill.total)}</span>
                </div>
                {collectBill.advance_amount && collectBill.advance_amount > 0 && (
                  <div className="flex justify-between text-zinc-600">
                    <span>Already Paid:</span>
                    <span className="font-semibold text-emerald-600">{formatINR(collectBill.advance_amount)}</span>
                  </div>
                )}
                <div className="flex justify-between font-semibold text-amber-700 border-t border-zinc-200 pt-1.5">
                  <span>Remaining Due:</span>
                  <span>{formatINR(getDueAmount(collectBill))}</span>
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="collect-amount" className="text-zinc-700 text-xs font-semibold">Amount to Collect</Label>
                <Input
                  id="collect-amount"
                  type="number"
                  step="0.01"
                  placeholder={`Max: ${formatINR(getDueAmount(collectBill))}`}
                  value={collectAmount}
                  onChange={(e) => setCollectAmount(e.target.value)}
                  className="border-zinc-200 bg-white text-zinc-900 placeholder:text-zinc-400 focus-visible:ring-indigo-600"
                  autoFocus
                />
              </div>
              <div className="space-y-2">
                <Label className="text-zinc-700 text-xs font-semibold">Payment Method</Label>
                <Select value={collectPaymentMethod} onValueChange={(val) => val && setCollectPaymentMethod(val as 'upi' | 'bank' | 'cash' | 'card')}>
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
            </div>
          )}
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setCollectBill(null)}
              className="border-zinc-200 text-zinc-700 hover:bg-zinc-100"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleCollectPayment}
              disabled={isCollecting}
              className="bg-emerald-600 hover:bg-emerald-500 text-white gap-1.5"
            >
              {isCollecting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Collecting...
                </>
              ) : (
                <>
                  <Wallet className="h-4 w-4" />
                  Collect Payment
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={!!deleteBillTarget} onOpenChange={(open) => !open && setDeleteBillTarget(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Delete Invoice</DialogTitle>
            <DialogDescription>
              Are you sure you want to permanently delete invoice{' '}
              <span className="font-semibold text-zinc-900">{deleteBillTarget?.bill_number}</span> for{' '}
              <span className="font-semibold text-zinc-900">{deleteBillTarget?.customer_name}</span>?
              This action cannot be undone. All payment history for this invoice will also be deleted.
            </DialogDescription>
          </DialogHeader>
          <div className="flex items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3">
            <span className="text-sm text-zinc-500">Invoice Total</span>
            <span className="font-semibold text-zinc-900">{deleteBillTarget && formatINR(deleteBillTarget.total)}</span>
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setDeleteBillTarget(null)}
              className="border-zinc-200 text-zinc-700 hover:bg-zinc-100"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleDeleteBill}
              disabled={isDeleting}
              className="bg-rose-600 hover:bg-rose-500 text-white gap-1.5"
            >
              {isDeleting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Deleting...
                </>
              ) : (
                <>
                  <Trash2 className="h-4 w-4" />
                  Delete Permanently
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
