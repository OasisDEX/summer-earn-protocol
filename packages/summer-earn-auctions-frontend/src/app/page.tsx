'use client'

import { AuctionTabs } from '@/components/AuctionTabs'

async function getActiveAuctions() {
  const response = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL}/api/getAuctions`, {
    next: { revalidate: 60 * 5 }, // 5 minutes
  })
  return response.json()
}

async function getFinishedAuctions() {
  const response = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL}/api/getFinishedAuctions`, {
    next: { revalidate: 60 * 15 }, // 15 minutes
  })
  return response.json()
}

export default async function Home() {
  const [activeAuctions, finishedAuctions] = await Promise.all([
    getActiveAuctions(),
    getFinishedAuctions(),
  ])

  return (
    <div className="container py-8 space-y-6">
      <h1 className="text-3xl font-bold">Summer Earn Auctions</h1>
      <AuctionTabs
        activeAuctions={activeAuctions.auctions}
        finishedAuctions={finishedAuctions.auctions}
      />
    </div>
  )
}
