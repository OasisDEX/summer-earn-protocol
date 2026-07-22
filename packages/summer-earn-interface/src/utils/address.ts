export function formatAddress(address?: string | null, chars: number = 4) {
  if (!address) return '—'
  if (address.length <= 2 + chars * 2) return address
  return `${address.slice(0, chars + 2)}…${address.slice(-chars)}`
}

export function formatHash(hash?: string | null, chars: number = 6) {
  return formatAddress(hash, chars)
}
