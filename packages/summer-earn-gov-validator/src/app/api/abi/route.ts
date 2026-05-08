import { NextRequest, NextResponse } from 'next/server'
import { Abi } from 'viem'

import { getAbiFetcher } from '@/lib/abi'
import { getCache, putCache } from '@/lib/dynamodb'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const address = searchParams.get('address')
  const chainId = searchParams.get('chainId')

  if (!address || !chainId) {
    return NextResponse.json({ error: 'Address and chainId are required' }, { status: 400 })
  }

  // 1. Check DynamoDB Cache
  const cacheKey = `ABI#${chainId}#${address.toLowerCase()}`
  const cached = await getCache<{ abi: Abi; implementationAddress?: string }>(cacheKey, 'DATA')
  if (cached) {
    console.log('ABI from cache')
    return NextResponse.json({
      abi: cached.abi,
      source: 'cache',
      ...(cached.implementationAddress && { implementationAddress: cached.implementationAddress }),
    })
  }

  let fetcher
  try {
    fetcher = await getAbiFetcher(chainId)
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Chain is not supported' },
      { status: 400 },
    )
  }

  try {
    let addressToFetch = address
    const parsedChainId = parseInt(chainId)
    // Check if the contract is a proxy and get implementation address
    const implementationAddress = await fetcher.getImplementationAddress(address, parsedChainId)
    if (implementationAddress) {
      addressToFetch = implementationAddress
    }

    // Fetch ABI using the selected provider (Blockscout, Sourcify, etc.)
    const abi = await fetcher.fetchAbi(addressToFetch, parsedChainId)

    // 2. Save to DynamoDB Cache
    await putCache(cacheKey, 'DATA', {
      abi,
      chainId,
      address: address.toLowerCase(),
      ...(addressToFetch !== address && { implementationAddress: addressToFetch }),
    })

    return NextResponse.json({
      abi,
      source: 'blockscout',
      ...(addressToFetch !== address && { implementationAddress: addressToFetch }),
    })
  } catch (error) {
    console.error('ABI Fetch Error:', error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'An error occurred' },
      { status: 500 },
    )
  }
}
