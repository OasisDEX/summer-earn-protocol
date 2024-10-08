import { BaseConfig } from '../../types/config-types'

export function checkExistingContracts<T extends { [key: string]: { address: string } }>(
  config: BaseConfig,
  mainKey: keyof typeof config.deployedContracts,
) {
  const typedMainKey = mainKey as keyof typeof config.deployedContracts
  const contractKeys = Object.keys(config.deployedContracts[typedMainKey])
  for (const key of contractKeys) {
    // @ts-ignore
    const address = config.deployedContracts[typedMainKey][key].address
    if (address && address !== '0x0000000000000000000000000000000000000000') {
      throw new Error(`${String(key)} is already deployed at ${address}. Cannot redeploy.`)
    }
  }
}
