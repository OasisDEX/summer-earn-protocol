import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export interface SparkArkContracts {
  sparkArk: {
    address: Address
  }
}

/**
 * Creates a SparkArk module for deployment
 * @param moduleName The name of the module
 * @returns The SparkArk module
 */
export function createSparkArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const sparkArk = m.contract('SparkArk', [
      m.getParameter('sparkPool'),
      m.getParameter('rewardsController'),
      m.getParameter('arkParams'),
    ])

    return { sparkArk }
  })
}
