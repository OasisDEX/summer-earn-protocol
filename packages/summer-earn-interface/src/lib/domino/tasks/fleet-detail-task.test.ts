import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import { getFleetDetailPayload } from './fleet-detail-task'

const FLEET = '0xf1Ee7000000000000000000000000000000000F1' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const
const USER = '0x0000000000000000000000000000000000000009' as const

const handlers = {
  [callKey(FLEET, 'name')]: 'Fleet One',
  [callKey(FLEET, 'symbol')]: 'FL1',
  [callKey(FLEET, 'asset')]: ASSET,
  [callKey(FLEET, 'totalAssets')]: 12345n,
  [callKey(FLEET, 'withdrawableTotalAssets')]: 12000n,
  [callKey(FLEET, 'decimals')]: 18,
  [callKey(FLEET, 'getConfig')]: {
    bufferArk: '0x0000000000000000000000000000000000000002',
    minimumBufferBalance: 100n,
    depositCap: 9000n,
    maxRebalanceOperations: 4n,
    stakingRewardsManager: '0x0000000000000000000000000000000000000003',
  },
  [callKey(ASSET, 'decimals')]: 6,
  [callKey(ASSET, 'symbol')]: 'USDC',
  [callKey(FLEET, 'balanceOf')]: 111n,
  [callKey(ASSET, 'balanceOf')]: 222n,
  [callKey(ASSET, 'allowance')]: 333n,
}

describe('getFleetDetailPayload', () => {
  it('throws 400 for an unsupported chainId', async () => {
    await expect(
      getFleetDetailPayload('42', FLEET, null, new MockStepExecutor(handlers)),
    ).rejects.toMatchObject({ message: 'Unsupported chainId', status: 400 })
  })

  it('returns the legacy payload without user info', async () => {
    const payload = await getFleetDetailPayload('8453', FLEET, null, new MockStepExecutor(handlers))
    expect(payload).toEqual({
      address: FLEET,
      name: 'Fleet One',
      symbol: 'FL1',
      asset: ASSET,
      totalAssets: '12345',
      withdrawableTotalAssets: '12000',
      depositCap: '9000',
      minimumBufferBalance: '100',
      maxRebalanceOperations: '4',
      assetDecimals: 6,
      assetSymbol: 'USDC',
      fleetDecimals: 18,
      userInfo: null,
    })
  })

  it('includes userInfo when a user is given', async () => {
    const payload = await getFleetDetailPayload('8453', FLEET, USER, new MockStepExecutor(handlers))
    expect(payload.userInfo).toEqual({
      balance: '111',
      underlyingBalance: '222',
      allowance: '333',
    })
  })

  it('maps failures to the three legacy 502 errors', async () => {
    await expect(
      getFleetDetailPayload(
        '8453',
        FLEET,
        null,
        new MockStepExecutor({ ...handlers, [callKey(FLEET, 'name')]: FAIL }),
      ),
    ).rejects.toMatchObject({ message: 'Failed to read fleet contract', status: 502 })
    await expect(
      getFleetDetailPayload(
        '8453',
        FLEET,
        null,
        new MockStepExecutor({ ...handlers, [callKey(ASSET, 'decimals')]: FAIL }),
      ),
    ).rejects.toMatchObject({ message: 'Failed to read asset contract', status: 502 })
    await expect(
      getFleetDetailPayload(
        '8453',
        FLEET,
        USER,
        new MockStepExecutor({ ...handlers, [callKey(ASSET, 'allowance')]: FAIL }),
      ),
    ).rejects.toMatchObject({ message: 'Failed to read user info', status: 502 })
  })
})
