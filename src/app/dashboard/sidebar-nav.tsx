'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { PlusCircle, FileText, Package, Users, Settings } from 'lucide-react'
import { cn } from '@/lib/utils'

export default function SidebarNav({ role }: { role: string }) {
  const pathname = usePathname()

  const links = [
    {
      name: 'Create Invoice',
      href: '/dashboard',
      icon: PlusCircle,
      exact: true
    },
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

  // Add settings link only for admin
  if (role === 'admin') {
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
