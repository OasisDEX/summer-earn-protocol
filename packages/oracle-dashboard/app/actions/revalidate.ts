'use server'

import { revalidateTag } from 'next/cache'

export async function invalidateActivityLog(network: string) {
  revalidateTag(`activity-log-${network}`, 'max')
}
