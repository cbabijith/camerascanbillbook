'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { PlusCircle, FileText, Package, Users, Settings } from 'lucide-react'
import { cn } from '@/lib/utils'

export default function BottomNav({ role }: { role: string }) {
  const pathname = usePathname()

  const links = [
    {
      name: 'Create',
      href: '/dashboard',
      icon: PlusCircle,
      exact: true
    },
    {
      name: 'History',
      href: '/dashboard/bills',
      icon: FileText
    },
    {
      name: 'Products',
      href: '/dashboard/products',
      icon: Package
    },
    {
      name: 'Customers',
      href: '/dashboard/customers',
      icon: Users
    }
  ]

  if (role === 'admin') {
    links.push({
      name: 'Settings',
      href: '/dashboard/settings',
      icon: Settings
    })
  }

  return (
    <nav className="fixed bottom-0 left-0 right-0 h-16 bg-white/90 backdrop-blur-md border-t border-zinc-200 flex items-center justify-around px-2 z-40 md:hidden pb-safe shadow-[0_-2px_10px_rgba(0,0,0,0.03)]">
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
              "flex flex-col items-center justify-center flex-1 py-1 text-[10px] font-medium transition-all duration-150 gap-1 select-none",
              isActive
                ? "text-indigo-600 scale-105 font-semibold"
                : "text-zinc-500 hover:text-zinc-900 active:scale-95"
            )}
          >
            <div className={cn(
              "p-1 rounded-md transition-colors",
              isActive ? "bg-indigo-50" : "bg-transparent"
            )}>
              <Icon className={cn("h-5 w-5 transition-transform", isActive ? "stroke-[2.5px]" : "stroke-[2px]")} />
            </div>
            <span>{link.name}</span>
          </Link>
        )
      })}
    </nav>
  )
}
