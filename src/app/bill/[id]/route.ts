import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const supabaseAdmin = createSupabaseClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )

    // Download the PDF from Supabase storage using the invoice UUID
    const { data, error } = await supabaseAdmin.storage
      .from('invoices')
      .download(`${id}.pdf`)

    if (error || !data) {
      console.error('Error fetching invoice PDF:', error)
      return new NextResponse('Invoice PDF not found', { status: 404 })
    }

    // Convert Blob to ArrayBuffer to stream response
    const arrayBuffer = await data.arrayBuffer()

    return new NextResponse(Buffer.from(arrayBuffer), {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'inline; filename="invoice.pdf"',
        'Cache-Control': 'public, max-age=31536000, immutable'
      }
    })
  } catch (err: any) {
    console.error('Invoice stream handler crash:', err)
    return new NextResponse('Internal Server Error', { status: 500 })
  }
}
