import { Address, BigInt } from '@graphprotocol/graph-ts'
import { ERC20 } from '../../generated/EntryPoint/ERC20'
import { Token } from '../../generated/schema'

export function getOrCreateToken(tokenAddress: Address): Token {
  let token = Token.load(tokenAddress)
  if (!token) {
    token = new Token(tokenAddress)
    const decimals = ERC20.bind(tokenAddress).try_decimals()
    if (decimals.reverted) {
      token.decimals = BigInt.fromI32(18)
    } else {
      token.decimals = BigInt.fromI32(decimals.value)
    }
    const maybeSymbol = ERC20.bind(tokenAddress).try_symbol()
    token.symbol = maybeSymbol.reverted ? tokenAddress.toHexString() : maybeSymbol.value
    const len = token.decimals.toI32() + 1
    token.precision = BigInt.fromString('10'.padEnd(len, '0'))
    token.address = tokenAddress
    token.save()
  }

  return token
}
