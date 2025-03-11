'use client';

import { useEffect, useState } from 'react';
import { AuctionCard } from '@/components/AuctionCard';
import { Auction } from '@/lib/types';
import { CHAIN_CONFIGS } from '@/lib/config';

export default function Home() {
  const [auctionsByChain, setAuctionsByChain] = useState<Array<{chainId: number, auctions: Auction[]}>>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchAuctions = async () => {
      try {
        const response = await fetch('/api/getAuctions');
        const data = await response.json();
        
        if (data.error) throw new Error(data.error);
        setAuctionsByChain(data.auctions);
        setError(null);
      } catch (err) {
        setError('Failed to fetch auctions');
      } finally {
        setLoading(false);
      }
    };

    fetchAuctions();
  }, []);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className="container mx-auto p-4">
      {auctionsByChain.map(({ chainId, auctions }) => (
        auctions.length > 0 && (
          <div key={chainId} className="mb-8">
            <h2 className="text-2xl font-bold mb-4 text-gray-800">
              {CHAIN_CONFIGS[chainId].name} Auctions
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {auctions.map((auction) => (
                <AuctionCard
                  key={`${chainId}-${auction.id}`}
                  auction={auction}
                  chainId={chainId}
                />
              ))}
            </div>
          </div>
        )
      ))}
    </div>
  );
} 