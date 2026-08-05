/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: 'summer-earn-gov-validator',
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

    // DynamoDB Table (On-Demand / Pay-Per-Request for low cost)
    const table = new sst.aws.Dynamo('GovernanceCache', {
      fields: {
        PK: 'string',
        SK: 'string',
      },
      primaryIndex: { hashKey: 'PK', rangeKey: 'SK' },
    })

    // Next.js App linked to DynamoDB table
    const app = new sst.aws.Nextjs('GovValidatorApp', {
      link: [table],
      environment: {
        DYNAMODB_TABLE_NAME: table.name,
        BASE_SUBGRAPH_URL:
          process.env.BASE_SUBGRAPH_URL ||
          process.env.NEXT_PUBLIC_BASE_SUBGRAPH_URL ||
          'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base',
        ARBITRUM_SUBGRAPH_URL:
          process.env.ARBITRUM_SUBGRAPH_URL ||
          process.env.NEXT_PUBLIC_ARBITRUM_SUBGRAPH_URL ||
          'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-arbitrum',
        SONIC_SUBGRAPH_URL:
          process.env.SONIC_SUBGRAPH_URL ||
          process.env.NEXT_PUBLIC_SONIC_SUBGRAPH_URL ||
          'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-sonic',
        MAINNET_SUBGRAPH_URL:
          process.env.MAINNET_SUBGRAPH_URL ||
          process.env.NEXT_PUBLIC_MAINNET_SUBGRAPH_URL ||
          'https://subgraph.staging.oasisapp.dev/summer-protocol-gov',
        HYPERLIQUID_SUBGRAPH_URL:
          process.env.HYPERLIQUID_SUBGRAPH_URL ||
          process.env.NEXT_PUBLIC_HYPERLIQUID_SUBGRAPH_URL ||
          'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-hyperliquid',
        TENDERLY_ACCESS_KEY: process.env.TENDERLY_ACCESS_KEY || '',
        ETHERSCAN_API_KEY: process.env.ETHERSCAN_API_KEY || process.env.API_KEY_ETHERSCAN || '',
        COINGECKO_API_KEY: process.env.COINGECKO_API_KEY || '',
        BLOCKSCOUT_API_KEY: process.env.BLOCKSCOUT_API_KEY || '',
        NEXT_PUBLIC_WALLETCONNECT_ID: process.env.NEXT_PUBLIC_WALLETCONNECT_ID || 'demo',
      },
    })

    return {
      appUrl: app.url,
      tableName: table.name,
    }
  },
})
