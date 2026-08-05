/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: 'summer-earn-interface',
      removal: input?.stage === 'production' ? 'retain' : 'remove',
      home: 'aws',
      providers: {
        aws: {
          profile: 'gov-validator-aws',
        },
      },
    }
  },
  async run() {
    const dotenv = await import('dotenv')
    const path = await import('path')

    // Load environment files from root and local package
    dotenv.config({ path: path.resolve('../../.env') })
    dotenv.config({ path: path.resolve('../../.env.local') })
    dotenv.config({ path: path.resolve('.env') })
    dotenv.config({ path: path.resolve('.env.local') })

    // Next.js App
    const app = new sst.aws.Nextjs('SummerEarnInterfaceApp', {
      environment: {
        NEXT_PUBLIC_WALLETCONNECT_ID:
          process.env.NEXT_PUBLIC_WALLETCONNECT_ID || '4bbc26c4859bdd6b5ebb7728e85557ec',
        BASE_RPC_URL: process.env.BASE_RPC_URL || '',
        MAINNET_RPC_URL: process.env.MAINNET_RPC_URL || '',
        ARBITRUM_RPC_URL: process.env.ARBITRUM_RPC_URL || '',
        SONIC_RPC_URL: process.env.SONIC_RPC_URL || '',
        OPTIMISM_RPC_URL: process.env.OPTIMISM_RPC_URL || '',
        HYPERLIQUID_RPC_URL: process.env.HYPERLIQUID_RPC_URL || '',
      },
    })

    return {
      appUrl: app.url,
    }
  },
})
