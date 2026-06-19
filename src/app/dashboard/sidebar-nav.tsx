'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { PlusCircle, FileText, Package, Users, Settings, BarChart3 } from 'lucide-react'
import { cn } from '@/lib/utils'

export default function SidebarNav({ role }: { role: string }) {
  const pathname = usePathname()

  const links: { name: string; href: string; icon: typeof FileText; exact?: boolean }[] = [
    {
      name: 'Invoice History',
      href: '/dashboard/bills',
      icon: FileText
    },
    {
      name: 'Products Catalogue',
      href: '/dashboard/products',
      icon: Package
    },
    {
      name: 'Customer List',
      href: '/dashboard/customers',
      icon: Users
    }
  ]

  // Staff can create invoices
  if (role !== 'admin') {
    links.unshift({
      name: 'Create Invoice',
      href: '/dashboard',
      icon: PlusCircle,
      exact: true
    })
  }

  // Admin gets analytics and settings
  if (role === 'admin') {
    links.unshift({
      name: 'Analytics',
      href: '/dashboard/analytics',
      icon: BarChart3,
      exact: true
    })
    links.push({
      name: 'System Settings',
      href: '/dashboard/settings',
      icon: Settings
    })
  }

  return (
    <nav className="space-y-1.5">
      {links.map((link) => {
        const Icon = link.icon
        const isActive = link.exact 
          ? pathname === link.href 
          : pathname.startsWith(link.href)

        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              "flex items-center gap-3 px-3 py-2 text-sm font-medium rounded-md transition-all duration-150",
              isActive 
                ? "bg-indigo-600 text-white shadow-lg shadow-indigo-500/10" 
                : "text-zinc-655 hover:text-zinc-900 hover:bg-zinc-200/50"
            )}
          >
            <Icon className="h-4 w-4 shrink-0" />
            <span>{link.name}</span>
          </Link>
        )
      })}
    </nav>
  )
}
