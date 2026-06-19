import { jsPDF } from 'jspdf'

function formatPDFCurrency(amount: number | string): string {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount
  if (isNaN(num)) return 'Rs. 0.00'
  const formatted = new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(num)
  return `Rs. ${formatted}`
}

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

interface BranchInfo {
  name: string
  address?: string
  phone?: string
  gstin?: string
}

// ═══════════════════════════════════════════════════
// Number to Indian Rupee words converter
// ═══════════════════════════════════════════════════
function numberToWords(num: number): string {
  if (num === 0) return 'Zero'

  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen']
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']

  function convertBelowHundred(n: number): string {
    if (n < 20) return ones[n]
    return tens[Math.floor(n / 10)] + (n % 10 ? ' ' + ones[n % 10] : '')
  }

  function convertBelowThousand(n: number): string {
    if (n < 100) return convertBelowHundred(n)
    return ones[Math.floor(n / 100)] + ' Hundred' + (n % 100 ? ' and ' + convertBelowHundred(n % 100) : '')
  }

  // Indian numbering: Lakhs and Crores
  const wholePart = Math.floor(num)
  const paisePart = Math.round((num - wholePart) * 100)

  let result = ''

  if (wholePart >= 10000000) {
    result += convertBelowThousand(Math.floor(wholePart / 10000000)) + ' Crore '
  }
  const afterCrore = wholePart % 10000000
  if (afterCrore >= 100000) {
    result += convertBelowHundred(Math.floor(afterCrore / 100000)) + ' Lakh '
  }
  const afterLakh = afterCrore % 100000
  if (afterLakh >= 1000) {
    result += convertBelowHundred(Math.floor(afterLakh / 1000)) + ' Thousand '
  }
  const afterThousand = afterLakh % 1000
  if (afterThousand > 0) {
    result += convertBelowThousand(afterThousand)
  }

  result = result.trim()
  if (!result) result = 'Zero'

  if (paisePart > 0) {
    result += ' and ' + convertBelowHundred(paisePart) + ' Paise'
  }

  return 'Rupees ' + result + ' Only'
}

// ═══════════════════════════════════════════════════
// Date/Time helpers
// ═══════════════════════════════════════════════════
function formatDate(iso: string): string {
  const d = new Date(iso)
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return `${String(d.getDate()).padStart(2, '0')}-${months[d.getMonth()]}-${d.getFullYear()}`
}

function formatTime(iso: string): string {
  const d = new Date(iso)
  let hours = d.getHours()
  const mins = String(d.getMinutes()).padStart(2, '0')
  const ampm = hours >= 12 ? 'PM' : 'AM'
  hours = hours % 12 || 12
  return `${hours}:${mins} ${ampm}`
}

// ═══════════════════════════════════════════════════
// Main PDF Generator — Professional Indian Tax Invoice
// ═══════════════════════════════════════════════════
export function generateInvoicePDF(bill: Bill, branch: BranchInfo | null): jsPDF {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
  const pageWidth = doc.internal.pageSize.getWidth() // 210
  const pageHeight = doc.internal.pageSize.getHeight() // 297
  const ML = 10 // margin left
  const MR = 10 // margin right
  const CW = pageWidth - ML - MR // content width (190)
  const RX = pageWidth - MR // right edge x

  let y = 10 // y cursor

  // ── Drawing helpers ──
  const drawRect = (x: number, yPos: number, w: number, h: number) => {
    doc.setDrawColor(0)
    doc.setLineWidth(0.3)
    doc.rect(x, yPos, w, h)
  }

  const drawHLine = (x1: number, x2: number, atY: number, weight = 0.3) => {
    doc.setDrawColor(0)
    doc.setLineWidth(weight)
    doc.line(x1, atY, x2, atY)
  }

  const drawVLine = (x: number, y1: number, y2: number, weight = 0.3) => {
    doc.setDrawColor(0)
    doc.setLineWidth(weight)
    doc.line(x, y1, x, y2)
  }

  // ══════════════════════════════════════════════════
  // SECTION 1: TOP BAR — "TAX INVOICE" title
  // ══════════════════════════════════════════════════
  const topBarH = 8
  doc.setFillColor(240, 240, 240)
  doc.rect(ML, y, CW, topBarH, 'FD')

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11)
  doc.setTextColor(0)
  doc.text('INVOICE', ML + CW / 2, y + 5.5, { align: 'center' })

  // Page info left
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(6.5)
  doc.text('Original Copy', RX - 3, y + 5, { align: 'right' })

  y += topBarH

  // ══════════════════════════════════════════════════
  // SECTION 2: COMPANY / SHOP DETAILS
  // ══════════════════════════════════════════════════
  const shopSectionStart = y
  const shopName = branch?.name || 'Camera Shop'

  // Shop name — large, bold, centered
  y += 7
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(16)
  doc.setTextColor(0)
  doc.text(shopName, ML + CW / 2, y, { align: 'center' })

  // Address line
  y += 5
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  doc.setTextColor(60, 60, 60)
  if (branch?.address) {
    doc.text(branch.address, ML + CW / 2, y, { align: 'center' })
    y += 3.5
  }

  // Phone
  if (branch?.phone) {
    doc.text(`Phone: ${branch.phone}`, ML + CW / 2, y, { align: 'center' })
    y += 3.5
  }

  // GSTIN
  if (branch?.gstin) {
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(8)
    doc.setTextColor(0)
    doc.text(`GSTIN: ${branch.gstin}`, ML + CW / 2, y, { align: 'center' })
    y += 3.5
  }

  y += 2
  const shopSectionH = y - shopSectionStart
  drawRect(ML, shopSectionStart, CW, shopSectionH)

  // ══════════════════════════════════════════════════
  // SECTION 3: INVOICE DETAILS GRID (2 columns)
  // ══════════════════════════════════════════════════
  const gridStart = y
  const gridRowH = 6.5
  const colMid = ML + CW / 2 // vertical divider

  // Row 1: Invoice Number | Customer Name
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(7.5)
  doc.setTextColor(0)
  doc.text('Invoice Number:', ML + 2, y + 4.5)
  doc.setFont('helvetica', 'normal')
  doc.text(bill.bill_number, ML + 35, y + 4.5)

  doc.setFont('helvetica', 'bold')
  doc.text('Customer Name:', colMid + 2, y + 4.5)
  doc.setFont('helvetica', 'normal')
  doc.text(bill.customer_name, colMid + 35, y + 4.5)
  y += gridRowH

  drawHLine(ML, RX, y)

  // Row 2: Invoice Date | Customer Phone
  doc.setFont('helvetica', 'bold')
  doc.text('Invoice Date:', ML + 2, y + 4.5)
  doc.setFont('helvetica', 'normal')
  doc.text(formatDate(bill.created_at), ML + 35, y + 4.5)

  doc.setFont('helvetica', 'bold')
  doc.text('Customer Phone:', colMid + 2, y + 4.5)
  doc.setFont('helvetica', 'normal')
  doc.text(bill.customer_phone, colMid + 35, y + 4.5)
  y += gridRowH

  drawHLine(ML, RX, y)

  // Row 3: Time | Payment Status
  doc.setFont('helvetica', 'bold')
  doc.text('Time:', ML + 2, y + 4.5)
  doc.setFont('helvetica', 'normal')
  doc.text(formatTime(bill.created_at), ML + 35, y + 4.5)

  doc.setFont('helvetica', 'bold')
  doc.text('Payment Status:', colMid + 2, y + 4.5)
  doc.setFont('helvetica', 'normal')
  const statusText = bill.payment_status.toUpperCase()
  if (bill.payment_status === 'paid') {
    doc.setTextColor(22, 130, 60)
  } else {
    doc.setTextColor(200, 30, 30)
  }
  doc.text(statusText, colMid + 35, y + 4.5)
  doc.setTextColor(0)
  y += gridRowH

  // Draw grid box + vertical divider
  const gridH = y - gridStart
  drawRect(ML, gridStart, CW, gridH)
  drawVLine(colMid, gridStart, y)

  // ══════════════════════════════════════════════════
  // SECTION 4: ITEMS TABLE
  // ══════════════════════════════════════════════════
  const tableStart = y
  const headerH = 7

  // Column positions (absolute x values)
  const cols = {
    sno:    { x: ML,        w: 12  },
    desc:   { x: ML + 12,   w: 98  },
    sku:    { x: ML + 110,  w: 30  },
    qty:    { x: ML + 140,  w: 15  },
    price:  { x: ML + 155,  w: 35  },
    amount: { x: ML + 160,  w: 30  },
  }

  // Table header background
  doc.setFillColor(235, 235, 235)
  doc.rect(ML, y, CW, headerH, 'FD')

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(7)
  doc.setTextColor(0)
  doc.text('S.No', cols.sno.x + cols.sno.w / 2, y + 5, { align: 'center' })
  doc.text('Item Description', cols.desc.x + 2, y + 5)
  doc.text('Serial No.', cols.sku.x + cols.sku.w / 2, y + 5, { align: 'center' })
  doc.text('Qty', cols.qty.x + cols.qty.w / 2, y + 5, { align: 'center' })
  doc.text('Unit Price', cols.price.x + cols.price.w - 2, y + 5, { align: 'right' })
  doc.text('Amount', cols.amount.x + cols.amount.w - 2, y + 5, { align: 'right' })

  // Draw vertical lines for header
  const colXPositions = [cols.desc.x, cols.sku.x, cols.qty.x, cols.price.x, cols.amount.x]

  y += headerH

  // Table rows
  const rowH = 8
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(7.5)

  bill.items.forEach((item, index) => {
    // Check if we need a new page
    if (y + rowH > pageHeight - 50) {
      // Draw border for current table section
      drawRect(ML, tableStart, CW, y - tableStart)
      colXPositions.forEach(cx => drawVLine(cx, tableStart, y))
      doc.addPage()
      y = 10
    }

    doc.setTextColor(0)

    // S.No
    doc.text(String(index + 1), cols.sno.x + cols.sno.w / 2, y + 5.5, { align: 'center' })

    // Description (name + brand)
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(7.5)
    doc.text(item.name, cols.desc.x + 2, y + 4)
    if (item.brand) {
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(6)
      doc.setTextColor(100, 100, 100)
      doc.text(item.brand, cols.desc.x + 2, y + 7)
      doc.setTextColor(0)
    }
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(7.5)

    // Serial No.
    doc.setFontSize(6.5)
    doc.text(item.sku, cols.sku.x + cols.sku.w / 2, y + 5.5, { align: 'center' })
    doc.setFontSize(7.5)

    // Qty
    doc.text(String(item.qty), cols.qty.x + cols.qty.w / 2, y + 5.5, { align: 'center' })

    // Unit price
    doc.text(formatPDFCurrency(item.sellingPrice), cols.price.x + cols.price.w - 2, y + 5.5, { align: 'right' })

    // Amount
    doc.setFont('helvetica', 'bold')
    doc.text(formatPDFCurrency(item.total), cols.amount.x + cols.amount.w - 2, y + 5.5, { align: 'right' })
    doc.setFont('helvetica', 'normal')

    y += rowH
    drawHLine(ML, RX, y, 0.15)
  })

  // ── Total row inside the table ──
  const totalRowH = 8
  doc.setFillColor(245, 245, 245)
  doc.rect(ML, y, CW, totalRowH, 'F')

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(0)
  doc.text('Total', cols.desc.x + 2, y + 5.5)

  // Sum qty
  const totalQty = bill.items.reduce((sum, item) => sum + item.qty, 0)
  doc.text(String(totalQty), cols.qty.x + cols.qty.w / 2, y + 5.5, { align: 'center' })

  doc.setFontSize(9)
  doc.text(formatPDFCurrency(bill.total), cols.amount.x + cols.amount.w - 2, y + 5.5, { align: 'right' })

  y += totalRowH

  // Draw the complete items table border + vertical column lines
  drawRect(ML, tableStart, CW, y - tableStart)
  colXPositions.forEach(cx => drawVLine(cx, tableStart, y))

  // ══════════════════════════════════════════════════
  // SECTION 5: AMOUNT IN WORDS
  // ══════════════════════════════════════════════════
  const wordsStart = y
  const wordsH = 8

  doc.setFont('helvetica', 'italic')
  doc.setFontSize(7.5)
  doc.setTextColor(0)
  doc.text('Amount in words:', ML + 2, y + 3)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(7.5)
  doc.text(numberToWords(Number(bill.total)), ML + 2, y + 6.5)

  drawRect(ML, wordsStart, CW, wordsH)
  y += wordsH

  // ══════════════════════════════════════════════════
  // SECTION 6: TOTALS
  // ══════════════════════════════════════════════════
  const breakdownStart = y
  let breakdownH = 0

  // Simple layout: Only show "Grand Total" inside a simple 11mm box
  const boxH = 11
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(10)
  doc.setTextColor(0)

  doc.text('Grand Total:', ML + 5, breakdownStart + 7.5)
  doc.text(formatPDFCurrency(bill.total), RX - 5, breakdownStart + 7.5, { align: 'right' })

  breakdownH = boxH
  y = breakdownStart + breakdownH

  drawRect(ML, breakdownStart, CW, breakdownH)

  // ══════════════════════════════════════════════════
  // SECTION 7: FOOTER — SIGNATURE & TERMS
  // ══════════════════════════════════════════════════
  const footerStart = y
  const footerH = 22

  // Left: Terms
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(6.5)
  doc.setTextColor(100, 100, 100)
  doc.text('Terms & Conditions:', ML + 2, y + 4)
  doc.setFontSize(6)
  doc.text('1. Goods once sold will not be taken back.', ML + 2, y + 8)
  doc.text('2. All disputes are subject to local jurisdiction.', ML + 2, y + 11.5)

  // Right: Authorized signatory
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(7)
  doc.setTextColor(60, 60, 60)
  doc.text(`For ${branch?.name || 'Camera Shop'}`, RX - 3, y + 5, { align: 'right' })

  doc.setFontSize(6.5)
  doc.setTextColor(130, 130, 130)
  doc.text('Authorized Signatory', RX - 3, y + 18, { align: 'right' })

  drawRect(ML, footerStart, CW, footerH)
  y += footerH

  // ══════════════════════════════════════════════════
  // BOTTOM STRIP: Computer generated notice
  // ══════════════════════════════════════════════════
  y += 1
  doc.setFont('helvetica', 'italic')
  doc.setFontSize(6)
  doc.setTextColor(140, 140, 140)
  doc.text(
    `Computer Generated Invoice by ${bill.profiles?.name || 'staff member'}. No Signature Required.`,
    ML + CW / 2, y + 2, { align: 'center' }
  )

  return doc
}

// ═══════════════════════════════════════════════════
// Export utilities
// ═══════════════════════════════════════════════════

/**
 * Generate a PDF Blob from a Bill for uploading or sharing.
 */
export function generateInvoiceBlob(bill: Bill, branch: BranchInfo | null): Blob {
  const doc = generateInvoicePDF(bill, branch)
  return doc.output('blob')
}

/**
 * Generate a PDF File object from a Bill for native sharing.
 */
export function generateInvoiceFile(bill: Bill, branch: BranchInfo | null): File {
  const blob = generateInvoiceBlob(bill, branch)
  return new File([blob], `${bill.bill_number}.pdf`, { type: 'application/pdf' })
}

/**
 * Trigger download of the generated PDF.
 */
export function downloadInvoicePDF(bill: Bill, branch: BranchInfo | null): void {
  const doc = generateInvoicePDF(bill, branch)
  doc.save(`${bill.bill_number}.pdf`)
}

/**
 * Open the generated PDF in a new browser tab for viewing/printing.
 */
export function openInvoicePDFInNewTab(bill: Bill, branch: BranchInfo | null): void {
  const doc = generateInvoicePDF(bill, branch)
  const blobUrl = doc.output('bloburl')
  window.open(blobUrl.toString(), '_blank')
}

/**
 * Generate PDF and trigger browser print dialog directly using a hidden iframe.
 */
export function printInvoicePDF(bill: Bill, branch: BranchInfo | null): void {
  const doc = generateInvoicePDF(bill, branch)
  const blob = doc.output('blob')
  const pdfUrl = URL.createObjectURL(blob)

  // Create a hidden iframe
  const iframe = document.createElement('iframe')
  iframe.style.position = 'absolute'
  iframe.style.width = '0px'
  iframe.style.height = '0px'
  iframe.style.border = 'none'
  iframe.style.overflow = 'hidden'
  iframe.src = pdfUrl

  document.body.appendChild(iframe)

  iframe.onload = () => {
    setTimeout(() => {
      iframe.contentWindow?.focus()
      iframe.contentWindow?.print()

      // Cleanup
      setTimeout(() => {
        document.body.removeChild(iframe)
        URL.revokeObjectURL(pdfUrl)
      }, 1000)
    }, 200)
  }
}
