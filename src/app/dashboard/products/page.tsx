import { getCurrentUserAndBranch } from '@/lib/auth-utils'
import { redirect } from 'next/navigation'
import { getCachedProducts } from '@/lib/cached-queries'
import dynamic from 'next/dynamic'

const ProductsList = dynamic(() => import('./products-list'))

export default async function ProductsPage() {
  const { user, branchId } = await getCurrentUserAndBranch()

  if (!user || !branchId) {
    redirect('/login')
  }

  const products = await getCachedProducts(branchId)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-zinc-900">Products Catalogue</h1>
        <p className="text-sm text-zinc-500">Manage cameras, lenses, tripods, and accessories for this branch.</p>
      </div>
      <ProductsList initialProducts={products || []} />
    </div>
  )
}

