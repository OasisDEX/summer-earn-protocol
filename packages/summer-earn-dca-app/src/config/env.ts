// All NEXT_PUBLIC_* env reads are funnelled through this module so the
// surface is small and grep-able. Anything new needs a typed accessor here.

export function getWalletConnectProjectId(): string {
  return process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo'
}
