'use server'

import { revalidateTag } from 'next/cache'

export async function revalidateVestingData() {
  try {
    revalidateTag('vesting-data', 'tags')
    return { success: true, now: Date.now() }
  } catch (err) {
    console.error('Error revalidating vesting data:', err)
    return { success: false, error: err instanceof Error ? err.message : 'Unknown error' }
  }
}
