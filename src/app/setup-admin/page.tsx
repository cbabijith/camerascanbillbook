import { checkIfSetupRequired } from '../actions/auth'
import { redirect } from 'next/navigation'
import SetupForm from './setup-form'

export default async function SetupAdminPage() {
  const isSetupRequired = await checkIfSetupRequired()

  if (!isSetupRequired) {
    redirect('/login')
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4 py-12 text-zinc-900">
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#e4e4e7_1px,transparent_1px),linear-gradient(to_bottom,#e4e4e7_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] opacity-50" />
      <SetupForm />
    </div>
  )
}
