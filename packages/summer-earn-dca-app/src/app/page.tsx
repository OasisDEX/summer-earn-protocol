import { redirect } from 'next/navigation'

// `/` is just an alias for `/portfolio` — keeps the brand root pointing at
// the primary workspace surface. `/portfolio/{address}` is the canonical
// per-owner URL.
export default function RootPage(): never {
  redirect('/portfolio')
}
