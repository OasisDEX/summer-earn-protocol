import * as Tenderly from '../src/tenderly'
import * as Utils from '../src/utils'

describe('e2e', () => {
  it('should test fork creation and cleanup', async () => {
    const atBlock = 19475802
    const network = 'mainnet'
    const walletAddress = '0x275f568287595D30E216b618da37897f4bbaB1B6'

    const tokens = Object.keys(Utils.tokenAddresses[network]) as Utils.TokenName[]
    const resp = await Tenderly.createFork({ network, atBlock })
    const forkId = resp.data.root_transaction.fork_id

    await Tenderly.setETHBalance({
      forkId,
      balance: Utils.tokenBalances['ETH'],
      walletAddress: walletAddress,
    })

    for (const token of tokens) {
      await Tenderly.setERC20TokenBalance({
        forkId,
        network,
        token,
        balance: Utils.tokenBalances[token],
        walletAddress: walletAddress,
      })
    }

    console.log(`Selected network: ${network}`)
    console.log(`Wallet address: ${walletAddress}`)
    console.log('-------------------------------------')
    console.log('*** FUNDS ***')
    console.log(`ETH - ${Utils.tokenBalances['ETH']}`)
    tokens.forEach((token) => {
      console.log(`${token} - ${Utils.tokenBalances[token]}`)
    })
    console.log('-------------------------------------')
    console.log('Fork created: ', `https://rpc.tenderly.co/fork/${forkId}`)

    await Tenderly.deleteFork(forkId)
    console.log('Fork removed: ', `https://rpc.tenderly.co/fork/${forkId}`)
  })
})
