export function getTokenDecimals(token: string) {
  let decimals: number
  switch (token) {
    case 'WBTC':
      decimals = 8
      break
    case 'USDC':
      decimals = 6
      break
    default:
      decimals = 18
      break
  }
  return decimals
}
