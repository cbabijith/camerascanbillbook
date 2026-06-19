export default function DashboardLoading() {
  return (
    <div className="space-y-6 w-full animate-pulse">
      {/* Linear progress bar at top */}
      <div className="fixed top-16 left-0 right-0 h-1 bg-zinc-200 z-50 overflow-hidden md:left-64">
        <div className="h-full w-1/3 bg-indigo-600 rounded-full animate-loading-progress"></div>
      </div>

      {/* Header Skeleton */}
      <div className="space-y-2 pt-2">
        <div className="h-8 w-48 bg-zinc-200 rounded-md"></div>
        <div className="h-4 w-96 bg-zinc-200 rounded-md max-w-full"></div>
      </div>

      {/* Cards/Table Skeleton */}
      <div className="border border-zinc-200 bg-white shadow-sm rounded-lg p-6 space-y-4">
        <div className="flex items-center justify-between pb-4 border-b border-zinc-100">
          <div className="h-9 w-64 bg-zinc-200 rounded-md"></div>
          <div className="h-9 w-24 bg-zinc-200 rounded-md"></div>
        </div>

        <div className="space-y-3">
          <div className="grid grid-cols-4 gap-4">
            <div className="h-5 bg-zinc-200 rounded col-span-2"></div>
            <div className="h-5 bg-zinc-200 rounded col-span-1"></div>
            <div className="h-5 bg-zinc-200 rounded col-span-1"></div>
          </div>
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="grid grid-cols-4 gap-4 py-3 border-t border-zinc-100">
              <div className="h-4 bg-zinc-100 rounded col-span-2"></div>
              <div className="h-4 bg-zinc-100 rounded col-span-1"></div>
              <div className="h-4 bg-zinc-100 rounded col-span-1"></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
