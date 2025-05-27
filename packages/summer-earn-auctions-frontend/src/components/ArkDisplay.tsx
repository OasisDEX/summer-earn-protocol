import { shortenAddress } from '@/lib/utils'

interface ArkDisplayProps {
  address: string
  commander: string
}

export function ArkDisplay({ address, commander }: ArkDisplayProps) {
  return (
    <div className="flex items-center gap-2">
      <div className="text-sm font-medium">{commander || 'Unknown Commander'}</div>
      <div className="text-xs text-muted-foreground">({shortenAddress(address)})</div>
    </div>
  )
}
