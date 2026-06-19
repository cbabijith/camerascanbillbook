'use client'

import { useState, useTransition } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { FileText, IndianRupee, TrendingUp, Wallet, Trophy, BarChart3, Loader2, Calendar, CreditCard, AlertCircle } from 'lucide-react'
import { formatINR } from '@/lib/utils'
import { fetchAnalytics } from '@/app/actions/billing'
import type { BranchAnalytics } from '@/lib/cached-queries'

type DateRange = 'today' | '7d' | '30d' | 'month' | 'all' | 'custom'

function getRange(range: DateRange, customStart?: string, customEnd?: string): { start: string; end: string } {
  const now = new Date()
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
  const endISO = end.toISOString()

  switch (range) {
    case 'today': {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      return { start: start.toISOString(), end: endISO }
    }
    case '7d': {
      const start = new Date(now)
      start.setDate(start.getDate() - 7)
      return { start: start.toISOString(), end: endISO }
    }
    case '30d': {
      const start = new Date(now)
      start.setDate(start.getDate() - 30)
      return { start: start.toISOString(), end: endISO }
    }
    case 'month': {
      const start = new Date(now.getFullYear(), now.getMonth(), 1)
      return { start: start.toISOString(), end: endISO }
    }
    case 'all': {
      return { start: '2000-01-01T00:00:00.000Z', end: endISO }
    }
    case 'custom': {
      if (customStart) {
        const s = new Date(customStart)
        const e = customEnd ? new Date(customEnd) : new Date(now)
        e.setDate(e.getDate() + 1)
        return { start: s.toISOString(), end: e.toISOString() }
      }
      return { start: '2000-01-01T00:00:00.000Z', end: endISO }
    }
  }
}

const METHOD_COLORS: Record<string, string> = {
  cash: 'bg-amber-500/10 text-amber-600 border-amber-200',
  upi: 'bg-indigo-500/10 text-indigo-600 border-indigo-200',
  card: 'bg-teal-500/10 text-teal-600 border-teal-200',
  bank: 'bg-violet-500/10 text-violet-600 border-violet-200',
}

function ageLabel(days: number): string {
  if (days <= 0) return 'Today'
  if (days === 1) return '1 day'
  if (days < 30) return `${days} days`
  const months = Math.floor(days / 30)
  return months === 1 ? '1 month' : `${months} months`
}

function ageColor(days: number): string {
  if (days <= 7) return 'text-emerald-600'
  if (days <= 30) return 'text-amber-600'
  if (days <= 60) return 'text-orange-600'
  return 'text-rose-600'
}

export default function AnalyticsView({ initialData }: { initialData: BranchAnalytics[] }) {
  const [data, setData] = useState<BranchAnalytics[]>(initialData)
  const [range, setRange] = useState<DateRange>('month')
  const [customStart, setCustomStart] = useState('')
  const [customEnd, setCustomEnd] = useState('')
  const [isPending, startTransition] = useTransition()
  const [activeTab, setActiveTab] = useState(data[0]?.branchId || 'all')

  const fetchData = (r: DateRange, cs?: string, ce?: string) => {
    const { start, end } = getRange(r, cs, ce)
    startTransition(async () => {
      const result = await fetchAnalytics(start, end)
      setData(result)
    })
  }

  const handleRangeChange = (r: DateRange) => {
    setRange(r)
    if (r !== 'custom') {
      fetchData(r)
    }
  }

  const handleCustomSearch = () => {
    fetchData('custom', customStart, customEnd)
  }

  const aggregate = data.reduce(
    (acc, b) => {
      acc.totalInvoices += b.totalInvoices
      acc.totalSales += b.totalSales
      acc.totalReceived += b.totalReceived
      acc.totalDue += b.totalDue
      acc.avgBillValue += b.avgBillValue
      return acc
    },
    { totalInvoices: 0, totalSales: 0, totalReceived: 0, totalDue: 0, avgBillValue: 0 }
  )
  aggregate.avgBillValue = data.length > 0 ? aggregate.avgBillValue / data.length : 0

  const allStaff = data
    .flatMap(b => b.staffRanking.map(s => ({ ...s, branchName: b.branchName })))
    .sort((a, b) => b.billCount - a.billCount || b.totalSales - a.totalSales)

  const allOverdue = data
    .flatMap(b => b.overdueDues)
    .sort((a, b) => b.age - a.age)

  const allMethods = new Map<string, { count: number; amount: number }>()
  for (const b of data) {
    for (const m of b.paymentMethodBreakdown) {
      const existing = allMethods.get(m.method) || { count: 0, amount: 0 }
      existing.count += m.count
      existing.amount += m.amount
      allMethods.set(m.method, existing)
    }
  }
  const methodBreakdown = Array.from(allMethods.entries())
    .map(([method, val]) => ({ method, ...val }))
    .sort((a, b) => b.amount - a.amount)

  const StatCard = ({
    icon: Icon,
    label,
    value,
    color,
  }: {
    icon: React.ElementType
    label: string
    value: string
    color: string
  }) => (
    <Card className="border-zinc-200 shadow-sm">
      <CardContent className="p-5">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500">{label}</p>
            <p className="text-2xl font-bold text-zinc-900 mt-1">{value}</p>
          </div>
          <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${color}`}>
            <Icon className="h-6 w-6" />
          </div>
        </div>
      </CardContent>
    </Card>
  )

  const rangeButtons: { label: string; value: DateRange }[] = [
    { label: 'Today', value: 'today' },
    { label: '7 Days', value: '7d' },
    { label: '30 Days', value: '30d' },
    { label: 'This Month', value: 'month' },
    { label: 'All Time', value: 'all' },
  ]

  const renderStatCards = (b: typeof aggregate) => (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
      <StatCard icon={FileText} label="Invoices" value={String(b.totalInvoices)} color="bg-indigo-500/10 text-indigo-600" />
      <StatCard icon={IndianRupee} label="Total Sales" value={formatINR(b.totalSales)} color="bg-emerald-500/10 text-emerald-600" />
      <StatCard icon={TrendingUp} label="Collected" value={formatINR(b.totalReceived)} color="bg-teal-500/10 text-teal-600" />
      <StatCard icon={Wallet} label="Outstanding Due" value={formatINR(b.totalDue)} color="bg-rose-500/10 text-rose-600" />
      <StatCard icon={BarChart3} label="Avg Bill Value" value={formatINR(b.avgBillValue)} color="bg-violet-500/10 text-violet-600" />
    </div>
  )

  const renderPaymentMethods = (methods: { method: string; count: number; amount: number }[]) => {
    if (methods.length === 0) {
      return <p className="text-sm text-zinc-500 text-center py-6">No payments collected in this period.</p>
    }
    const maxAmount = Math.max(...methods.map(m => m.amount))
    return (
      <div className="space-y-3">
        {methods.map(m => (
          <div key={m.method} className="space-y-1.5">
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center gap-2">
                <Badge className={`${METHOD_COLORS[m.method] || 'bg-zinc-100 text-zinc-600 border-zinc-200'} uppercase text-xs`}>
                  {m.method}
                </Badge>
                <span className="text-zinc-500 text-xs">{m.count} transactions</span>
              </div>
              <span className="font-bold text-zinc-900">{formatINR(m.amount)}</span>
            </div>
            <div className="h-2 rounded-full bg-zinc-100 overflow-hidden">
              <div
                className="h-full rounded-full bg-indigo-500"
                style={{ width: `${(m.amount / maxAmount) * 100}%` }}
              />
            </div>
          </div>
        ))}
      </div>
    )
  }

  const renderOverdueDues = (dues: { billNumber: string; customerName: string; amount: number; age: number; branchName: string }[], showBranch: boolean) => {
    if (dues.length === 0) {
      return <p className="text-sm text-zinc-500 text-center py-6">No outstanding dues. All paid up!</p>
    }
    return (
      <div className="space-y-2 max-h-80 overflow-y-auto">
        {dues.map((d, idx) => (
          <div key={idx} className="flex items-center gap-3 rounded-lg border border-zinc-200 px-3 py-2.5">
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-zinc-800 truncate">
                {d.billNumber} — {d.customerName}
              </p>
              {showBranch && <p className="text-xs text-zinc-500">{d.branchName}</p>}
            </div>
            <div className="text-right">
              <p className="text-sm font-bold text-rose-600">{formatINR(d.amount)}</p>
              <p className={`text-xs ${ageColor(d.age)}`}>{ageLabel(d.age)} overdue</p>
            </div>
          </div>
        ))}
      </div>
    )
  }

  const renderStaffRanking = (staff: typeof allStaff, showBranch: boolean) => {
    if (staff.length === 0) {
      return <p className="text-sm text-zinc-500 text-center py-8">No staff activity in this period.</p>
    }
    return (
      <div className="space-y-2">
        {staff.map((s, idx) => (
          <div
            key={`${s.name}-${s.branchName}`}
            className={`flex items-center gap-3 rounded-lg px-3 py-2.5 ${
              idx === 0 ? 'bg-amber-50 border border-amber-200'
              : idx === 1 ? 'bg-zinc-50 border border-zinc-200'
              : idx === 2 ? 'bg-orange-50 border border-orange-200'
              : 'border border-transparent'
            }`}
          >
            <div className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-bold ${
              idx === 0 ? 'bg-amber-500 text-white'
              : idx === 1 ? 'bg-zinc-400 text-white'
              : idx === 2 ? 'bg-orange-500 text-white'
              : 'bg-zinc-200 text-zinc-600'
            }`}>
              {idx + 1}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-zinc-800 truncate">{s.name}</p>
              {showBranch && <p className="text-xs text-zinc-500">{s.branchName}</p>}
            </div>
            <div className="text-right">
              <p className="text-sm font-bold text-zinc-900">{s.billCount}</p>
              <p className="text-xs text-zinc-500">invoices</p>
            </div>
            <div className="text-right pl-2 border-l border-zinc-200">
              <p className="text-sm font-bold text-emerald-600">{formatINR(s.totalSales)}</p>
              <p className="text-xs text-zinc-500">sales</p>
            </div>
            <div className="text-right pl-2 border-l border-zinc-200">
              <p className="text-sm font-bold text-teal-600">{formatINR(s.collectedAmount)}</p>
              <p className="text-xs text-zinc-500">collected</p>
            </div>
          </div>
        ))}
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Analytics Dashboard</h1>
          <p className="text-sm text-zinc-500">Business overview across all branches with staff performance ranking.</p>
        </div>
      </div>

      {/* Date Range Filter */}
      <Card className="border-zinc-200 shadow-sm">
        <CardContent className="p-4">
          <div className="flex flex-col lg:flex-row lg:items-center gap-3">
            <div className="flex items-center gap-2 text-sm font-medium text-zinc-600">
              <Calendar className="h-4 w-4" />
              Date Range:
            </div>
            <div className="flex flex-wrap gap-2">
              {rangeButtons.map(rb => (
                <Button
                  key={rb.value}
                  type="button"
                  variant={range === rb.value ? 'default' : 'outline'}
                  size="sm"
                  onClick={() => handleRangeChange(rb.value)}
                  disabled={isPending}
                  className={range === rb.value ? 'bg-indigo-600 text-white' : 'border-zinc-200 text-zinc-600'}
                >
                  {rb.label}
                </Button>
              ))}
              <Button
                type="button"
                variant={range === 'custom' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setRange('custom')}
                disabled={isPending}
                className={range === 'custom' ? 'bg-indigo-600 text-white' : 'border-zinc-200 text-zinc-600'}
              >
                Custom
              </Button>
            </div>
            {range === 'custom' && (
              <div className="flex flex-wrap items-center gap-2">
                <Input type="date" value={customStart} onChange={e => setCustomStart(e.target.value)} className="w-40" />
                <span className="text-zinc-400 text-sm">to</span>
                <Input type="date" value={customEnd} onChange={e => setCustomEnd(e.target.value)} className="w-40" />
                <Button type="button" size="sm" onClick={handleCustomSearch} disabled={isPending || !customStart} className="bg-indigo-600 text-white">
                  {isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Apply'}
                </Button>
              </div>
            )}
            {isPending && (
              <div className="flex items-center gap-2 text-sm text-zinc-500">
                <Loader2 className="h-4 w-4 animate-spin" />
                Loading...
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="bg-zinc-100 border border-zinc-200">
          <TabsTrigger value="all" className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">
            <BarChart3 className="h-4 w-4 mr-1.5" />
            All Branches
          </TabsTrigger>
          {data.map(branch => (
            <TabsTrigger key={branch.branchId} value={branch.branchId} className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white">
              {branch.branchName}
            </TabsTrigger>
          ))}
        </TabsList>

        {/* All Branches Overview */}
        <TabsContent value="all" className="space-y-6 mt-4">
          {renderStatCards(aggregate)}

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Payment Method Breakdown */}
            <Card className="border-zinc-200 shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <CreditCard className="h-5 w-5 text-indigo-500" />
                  Payment Methods
                </CardTitle>
              </CardHeader>
              <CardContent>
                {renderPaymentMethods(methodBreakdown)}
              </CardContent>
            </Card>

            {/* Staff Leaderboard */}
            <Card className="border-zinc-200 shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <Trophy className="h-5 w-5 text-amber-500" />
                  Staff Leaderboard
                </CardTitle>
              </CardHeader>
              <CardContent>
                {renderStaffRanking(allStaff, true)}
              </CardContent>
            </Card>

            {/* Outstanding Dues */}
            <Card className="border-zinc-200 shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <AlertCircle className="h-5 w-5 text-rose-500" />
                  Outstanding Dues
                </CardTitle>
              </CardHeader>
              <CardContent>
                {renderOverdueDues(allOverdue, true)}
              </CardContent>
            </Card>
          </div>

          {/* Branch Comparison */}
          <Card className="border-zinc-200 shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg">Branch Comparison</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {data.map(branch => (
                  <div key={branch.branchId} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium text-zinc-700">{branch.branchName}</span>
                      <Badge className="bg-zinc-100 text-zinc-600 border border-zinc-200 text-xs">
                        {branch.totalInvoices} invoices
                      </Badge>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
                      <div className="rounded-lg bg-emerald-50 border border-emerald-100 px-3 py-2">
                        <p className="text-emerald-600 font-semibold">Sales</p>
                        <p className="text-emerald-900 font-bold mt-0.5">{formatINR(branch.totalSales)}</p>
                      </div>
                      <div className="rounded-lg bg-teal-50 border border-teal-100 px-3 py-2">
                        <p className="text-teal-600 font-semibold">Collected</p>
                        <p className="text-teal-900 font-bold mt-0.5">{formatINR(branch.totalReceived)}</p>
                      </div>
                      <div className="rounded-lg bg-rose-50 border border-rose-100 px-3 py-2">
                        <p className="text-rose-600 font-semibold">Due</p>
                        <p className="text-rose-900 font-bold mt-0.5">{formatINR(branch.totalDue)}</p>
                      </div>
                      <div className="rounded-lg bg-violet-50 border border-violet-100 px-3 py-2">
                        <p className="text-violet-600 font-semibold">Avg Bill</p>
                        <p className="text-violet-900 font-bold mt-0.5">{formatINR(branch.avgBillValue)}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Per-Branch Tabs */}
        {data.map(branch => (
          <TabsContent key={branch.branchId} value={branch.branchId} className="space-y-6 mt-4">
            {renderStatCards({
              totalInvoices: branch.totalInvoices,
              totalSales: branch.totalSales,
              totalReceived: branch.totalReceived,
              totalDue: branch.totalDue,
              avgBillValue: branch.avgBillValue,
            })}

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <Card className="border-zinc-200 shadow-sm">
                <CardHeader>
                  <CardTitle className="text-lg flex items-center gap-2">
                    <CreditCard className="h-5 w-5 text-indigo-500" />
                    Payment Methods
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {renderPaymentMethods(branch.paymentMethodBreakdown)}
                </CardContent>
              </Card>

              <Card className="border-zinc-200 shadow-sm">
                <CardHeader>
                  <CardTitle className="text-lg flex items-center gap-2">
                    <Trophy className="h-5 w-5 text-amber-500" />
                    Staff Ranking
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {renderStaffRanking(
                    branch.staffRanking.map(s => ({ ...s, branchName: branch.branchName })),
                    false
                  )}
                </CardContent>
              </Card>

              <Card className="border-zinc-200 shadow-sm">
                <CardHeader>
                  <CardTitle className="text-lg flex items-center gap-2">
                    <AlertCircle className="h-5 w-5 text-rose-500" />
                    Outstanding Dues
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {renderOverdueDues(branch.overdueDues, false)}
                </CardContent>
              </Card>
            </div>
          </TabsContent>
        ))}
      </Tabs>
    </div>
  )
}

