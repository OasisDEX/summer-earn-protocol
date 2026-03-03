'use server'

import { revalidateTag } from 'next/cache'

export async function invalidateActivityLog(network: string) {
    // @ts-expect-error - Next.js 15 type definitions might expect 2 args in some versions
    revalidateTag(`activity-log-${network}`)
}
