import { revalidateTag } from 'next/cache'
import { NextResponse } from 'next/server'

export async function POST(req: Request) {
  const secret = req.headers.get('x-revalidate-secret')
  if (!secret || secret !== process.env.REVALIDATE_SECRET) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 })
  }

  let body: { tag?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'invalid JSON body' }, { status: 400 })
  }

  const { tag } = body
  if (!tag) {
    return NextResponse.json({ error: 'tag required' }, { status: 400 })
  }

  revalidateTag(tag, 'max')
  return NextResponse.json({ revalidated: tag })
}
