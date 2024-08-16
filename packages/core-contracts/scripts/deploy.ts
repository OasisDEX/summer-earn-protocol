import hre from 'hardhat'
import ProtocolCore, {ProtocolCoreContracts} from '../ignition/modules/protocol-core'
import {getConfigByNetwork} from "./config-handler";
import {ModuleLogger} from "./module-logger";

async function main() {
  const config = getConfigByNetwork(hre.network.name)
  const deployedProtocolCore = (await hre.ignition.deploy(
    ProtocolCore,
    {
      parameters: {
        ProtocolCore: {
          swapProvider: config.swapProvider,
          treasury: config.treasury,
        },
      },
    },
  )) as ProtocolCoreContracts;

  // Logging
  ModuleLogger.logProtocolCore(deployedProtocolCore);
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
