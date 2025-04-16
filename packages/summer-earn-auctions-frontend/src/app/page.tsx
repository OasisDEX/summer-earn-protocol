import { AuctionTabs } from '@/components/AuctionTabs'
import { getAllAuctions } from '@/lib/getters/getAuctions'
import { getAllFinishedAuctions } from '@/lib/getters/getFinishedAuctions'

export default async function Home() {
  const [activeAuctions, finishedAuctions] = await Promise.all([
    getAllAuctions(),
    getAllFinishedAuctions(),
  ])

  return (
    <div className="container py-8 space-y-6">
      <h1 className="text-3xl font-bold">Summer Earn Auctions</h1>
      <AuctionTabs activeAuctions={activeAuctions} finishedAuctions={finishedAuctions} />
    </div>
  )
}
