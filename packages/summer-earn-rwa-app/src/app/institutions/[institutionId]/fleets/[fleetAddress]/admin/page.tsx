import { redirect } from 'next/navigation'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function AdminLandingPage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  redirect(`/institutions/${institutionId}/fleets/${fleetAddress}/admin/whitelist`)
}
