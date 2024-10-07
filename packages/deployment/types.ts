import 'hardhat/types/config'

declare module 'hardhat/types/config' {
  interface ProjectPathsConfig {
    multiSources?: string[]
  }
}
