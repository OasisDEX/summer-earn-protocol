import { extendConfig, task } from 'hardhat/config'
import { HardhatConfig, HardhatUserConfig } from 'hardhat/types'
import { resolve } from 'path'

extendConfig((config: HardhatConfig, userConfig: Readonly<HardhatUserConfig>) => {
  config.paths.multiSources = [
    resolve(__dirname, '../../gov-contracts/src'),
    resolve(__dirname, '../../core-contracts/src'),
    resolve(__dirname, '../../rewards-contracts/src'),
  ]
})

task('compile', 'Compiles the entire project').setAction(async (_, hre, runSuper) => {
  const originalSources = hre.config.paths.sources
  for (const sourcePath of hre.config.paths.multiSources || []) {
    console.log(`Compiling sources from: ${sourcePath}`)
    hre.config.paths.sources = sourcePath

    // Allow compilation of contracts outside the project

    hre.config.paths.root = resolve(sourcePath, '..')

    await runSuper()
  }

  // Restore original paths

  hre.config.paths.sources = originalSources

  hre.config.paths.root = process.cwd()
})
