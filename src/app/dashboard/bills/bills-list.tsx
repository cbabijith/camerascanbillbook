'use client'

import { useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent, DialogFooter } from '@/components/ui/dialog'
import { Search, Eye, Share2, Printer, Loader2 } from 'lucide-react'
import { format } from 'date-fns'
import { formatINR } from '@/lib/utils'
import { toast } from 'sonner'
import { generateInvoiceFile, generateInvoiceBlob, downloadInvoicePDF, printInvoicePDF } from '@/lib/pdf-generator'
import { createClient } from '@/lib/supabase/client'

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

interface Bill {
  id: string
  bill_number: string
  customer_name: string
  customer_phone: string
  sub_total: number
  gst_amount: number
  total: number
  payment_status: 'paid' | 'unpaid'
  created_at: string
  items: BillItem[]
  profiles?: {
    name: string
  }
}

interface BillsListProps {
  initialBills: Bill[]
  activeBranch: {
    name: string
    address?: string
    phone?: string
    gstin?: string
  } | null
}

export default function BillsList({ initialBills, activeBranch }: BillsListProps) {
  const [search, setSearch] = useState('')
  const [selectedBill, setSelectedBill] = useState<Bill | null>(null)
  const [isReceiptOpen, setIsReceiptOpen] = useState(false)
  const [sharingBillId, setSharingBillId] = useState<string | null>(null)

  // Filter bills based on search query
  const filteredBills = initialBills.filter((bill) => {
    const term = search.toLowerCase()
    return (
      bill.bill_number.toLowerCase().includes(term) ||
      bill.customer_name.toLowerCase().includes(term) ||
      bill.customer_phone.includes(term)
    )
  })

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

  // Handle print — generates PDF and triggers print dialog
  const handlePrint = () => {
    if (selectedBill) {
      printInvoicePDF(selectedBill, activeBranch)
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
                            : 'bg-rose-500/10 text-rose-600 border border-rose-200'
                        }
                      >
                        {bill.payment_status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-zinc-500 text-xs">{bill.profiles?.name || 'Unknown'}</TableCell>
                    <TableCell>
                      <div className="flex items-center justify-center gap-1.5">
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
          filteredBills.map((bill) => (
            <Card key={bill.id} className="border-zinc-200 bg-white shadow-sm">
              <CardContent className="p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-zinc-800 text-sm">{bill.bill_number}</span>
                  <Badge
                    className={
                      bill.payment_status === 'paid'
                        ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-200 text-[10px]'
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
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
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
                    <div className="flex justify-between font-bold text-zinc-900 border-t border-zinc-200 pt-2 text-base print:text-black print:border-zinc-300">
                      <span>Grand Total:</span>
                      <span className="font-mono text-indigo-600 print:text-black">{formatINR(selectedBill.total)}</span>
                    </div>
                  </div>
                </div>

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
    </div>
  )
}
