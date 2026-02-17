import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'
import prompts from 'prompts'
import { Address, createPublicClient, encodeFunctionData, getAddress, http } from 'viem'

import chalk from 'chalk'
import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import { readInstitutionConfigFile } from '../helpers/institution-config'
dotenv.config({ path: '../../.env' })

enum Token {
  USDC = 'usdc',
  DAI = 'dai',
  USDT = 'usdt',
  USDE = 'usde',
  USDCE = 'usdce',
  USDS = 'usds',
  STAKED_USDS = 'stakedUsds',
  WETH = 'weth',
  STETH = 'steth',
  EURC = 'eurc',
  SEAM = 'seam',
  REUL = 'reul',
  WELL = 'well',
  WS = 'ws',
  GEAR = 'gear',
  MORPHO = 'morpho',
  SYRUP = 'syrup',
  SILO = 'silo',
  SKY = 'sky',
  XSILO = 'xsilo',
  COMP = 'comp',
  SPK = 'spk',
  USDF = 'usdf',
  EXTRA = 'extra',
  ARB = 'arb',
  ASONWS = 'asonws',
  FLUID = 'fluid',
}
const addresses: Record<
  SupportedChain,
  {
    raft: string
    tokens: Partial<Record<Token, string>>
  }
> = {
  base: {
    raft: '0x7839d904D05d3D6B5F1D87eb93e1dcD5746AbC6E',
    tokens: {
      usdc: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      dai: '0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb',
      weth: '0x4200000000000000000000000000000000000006',
      usds: '0x820C137fa70C8691f0e44Dc420a5e53c168921Dc',
      stakedUsds: '0x5875eEE11Cf8398102FdAd704C9E96607675467a',
      morpho: '0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842',
      reul: '0xE08e1f00D388E201e48842E53fA96195568e6813',
      eurc: '0x60a3e35cc302bfa44cb288bc5a4f316fdb1adb42',
      seam: '0x1C7a460413dD4e964f96D8dFC56E7223cE88CD85',
      ws: '0x0000000000000000000000000000000000000000',
      well: '0xA88594D404727625A9437C3f886C7643872296AE',
      gear: '0x0000000000000000000000000000000000000000',
      usdt: '0x6047828dc181963ba44974801FF68e538dA5eaF9',
      usde: '0x0000000000000000000000000000000000000000',
      xsilo: '0x0000000000000000000000000000000000000000',
      comp: '0x9e1028F5F1D5eDE59748FFceE5532509976840E0',
      spk: '0x0000000000000000000000000000000000000000',
      usdf: '0x0000000000000000000000000000000000000000',
      extra: '0x2dAD3a13ef0C6366220f989157009e501e7938F8',
      arb: '0x0000000000000000000000000000000000000000',
      asonws: '0x0000000000000000000000000000000000000000',
      fluid: '0x61E030A56D33e8260FdD81f03B162A79Fe3449Cd',
    },
  },
  mainnet: {
    raft: '0xEcCd16aA1ae0B32b231a3B5FFE8567aBf68616E2',
    tokens: {
      usdc: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      weth: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
      usds: '0xdC035D45d973E3EC169d2276DDab16f1e407384F',
      stakedUsds: '0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD',
      usdt: '0xdac17f958d2ee523a2206206994597c13d831ec7',
      morpho: '0x58D97B57BB95320F9a05dC918Aef65434969c2B2',
      reul: '0xf3e621395fc714b90da337aa9108771597b4e696',
      seam: '0x0000000000000000000000000000000000000000',
      ws: '0x0000000000000000000000000000000000000000',
      gear: '0xBa3335588D9403515223F109EdC4eB7269a9Ab5D',
      syrup: '0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66',
      sky: '0x56072C95FAA701256059aa122697B133aDEd9279',
      xsilo: '0xdd4c6fd31ccf66e250790643947675153c221a91',
      silo: '0xF0B2dd79324A66d2108C961d680F7616E1486bB0',
      comp: '0xc00e94cb662c3520282e6f5717214004a7f26888',
      spk: '0xc20059e0317DE91738d13af027DfC4a50781b066',
      usdf: '0xFa2B947eEc368f42195f24F36d2aF29f7c24CeC2',
      extra: '0x0000000000000000000000000000000000000000',
      arb: '0x0000000000000000000000000000000000000000',
      asonws: '0x0000000000000000000000000000000000000000',
      fluid: '0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb',
    },
  },
  sonic: {
    raft: '0x2a828B0E5cB549eE568923E815D9A781b6f4F018',
    tokens: {
      usdce: '0x29219dd400f2Bf60E5a23d13Be72B486D4038894',
      dai: '0x0000000000000000000000000000000000000000',
      weth: '0x50c42dEAcD8Fc9773493ED674b675bE577f2634b',
      usds: '0x0000000000000000000000000000000000000000',
      stakedUsds: '0x0000000000000000000000000000000000000000',
      usdt: '0x6047828dc181963ba44974801FF68e538dA5eaF9',
      seam: '0x0000000000000000000000000000000000000000',
      ws: '0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38',
      reul: '0x0000000000000000000000000000000000000000',
      silo: '0xb098AFC30FCE67f1926e735Db6fDadFE433E61db',
      xsilo: '0x4451765739b2D7BCe5f8BC95Beaf966c45E1Dcc9',
      comp: '0x0000000000000000000000000000000000000000',
      spk: '0x0000000000000000000000000000000000000000',
      usdf: '0x0000000000000000000000000000000000000000',
      extra: '0x0000000000000000000000000000000000000000',
      arb: '0x0000000000000000000000000000000000000000',
      asonws: '0x6C5E14A212c1C3e4Baf6f871ac9B1a969918c131',
    },
  },
  arbitrum: {
    raft: '0x60A81C58F37527FdEcc968FC8B834Ed00b65926d',
    tokens: {
      usdc: '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
      dai: '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
      usde: '0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34',
      usdt: '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
      usdce: '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8',
      weth: '0x82af49447d8a07e3bd95bd0d56f35241523fbab1',
      morpho: '0x40BD670A58238e6E230c430BBb5cE6ec0d40df48',
      reul: '0x0000000000000000000000000000000000000000',
      seam: '0x0000000000000000000000000000000000000000',
      ws: '0x0000000000000000000000000000000000000000',
      xsilo: '0xf3775f959bc64923bd809085299dbc984d3e6c8a',
      comp: '0x354A6dA3fcde098F8389cad84b0182725c6C91dE',
      spk: '0x0000000000000000000000000000000000000000',
      usdf: '0x0000000000000000000000000000000000000000',
      extra: '0x0000000000000000000000000000000000000000',
      arb: '0x912CE59144191C1204E64559FE8253a0e49E6548',
      asonws: '0x0000000000000000000000000000000000000000',
      fluid: '0x61E030A56D33e8260FdD81f03B162A79Fe3449Cd',
    },
  },
}

enum SupportedChain {
  base = 'base',
  arbitrum = 'arbitrum',
  mainnet = 'mainnet',
  sonic = 'sonic',
}

const SUPPORTED_CHAINS = [
  SupportedChain.base,
  SupportedChain.arbitrum,
  SupportedChain.mainnet,
  SupportedChain.sonic,
]

const RPC_URL_MAP = {
  [SupportedChain.mainnet]: process.env.MAINNET_RPC_URL,
  [SupportedChain.base]: process.env.BASE_RPC_URL,
  [SupportedChain.arbitrum]: process.env.ARBITRUM_RPC_URL,
  [SupportedChain.sonic]: process.env.SONIC_RPC_URL,
}

const VIEM_CHAIN_MAP = {
  [SupportedChain.mainnet]: mainnet,
  [SupportedChain.base]: base,
  [SupportedChain.arbitrum]: arbitrum,
  [SupportedChain.sonic]: sonic,
}

// Hardcoded ABIs - these will be replaced with actual ABIs
const FLEET_COMMANDER_ABI = [
  // Add your FleetCommander ABI here
  {
    inputs: [],
    name: 'getConfig',
    outputs: [
      { name: 'bufferArk', type: 'address' },
      { name: 'depositCap', type: 'uint256' },
      { name: 'minimumBufferBalance', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getCooldown',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'cap', type: 'uint256' }],
    name: 'setFleetDepositCap',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'balance', type: 'uint256' }],
    name: 'setMinimumBufferBalance',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'cooldown', type: 'uint256' }],
    name: 'updateRebalanceCooldown',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'cap', type: 'uint256' },
    ],
    name: 'setArkDepositCap',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'percentage', type: 'uint256' },
    ],
    name: 'setArkMaxDepositPercentageOfTVL',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'setArkMaxRebalanceInflow',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'setArkMaxRebalanceOutflow',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
]

const ARK_ABI = [
  // Add your Ark ABI here
  {
    inputs: [],
    name: 'depositCap',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'maxDepositPercentageOfTVL',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'maxRebalanceInflow',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'maxRebalanceOutflow',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
]

const RAFT_ABI = [
  // Add your Raft ABI here
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'rewardTokenAddress', type: 'address' },
    ],
    name: 'sweepableTokens',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'rewardTokenAddress', type: 'address' },
    ],
    name: 'arkAuctionParameters',
    outputs: [
      { name: 'duration', type: 'uint256' },
      { name: 'startPrice', type: 'uint256' },
      { name: 'endPrice', type: 'uint256' },
      { name: 'kickerRewardPercentage', type: 'uint256' },
      { name: 'decayType', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'rewardTokenAddress', type: 'address' },
      {
        name: 'params',
        type: 'tuple',
        components: [
          { name: 'duration', type: 'uint40' },
          { name: 'startPrice', type: 'uint256' },
          { name: 'endPrice', type: 'uint256' },
          { name: 'kickerRewardPercentage', type: 'uint256' },
          { name: 'decayType', type: 'uint8' },
        ],
      },
    ],
    name: 'setArkAuctionParameters',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'rewardTokenAddress', type: 'address' },
      { name: 'isSweepable', type: 'bool' },
    ],
    name: 'setSweepableToken',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
]

dotenv.config()

if (!process.env.CURATOR_MULTISIG_ADDRESS) {
  throw new Error('❌ CURATOR_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.CURATOR_MULTISIG_PROPOSER_PRIV_KEY) {
  throw new Error('❌ CURATOR_MULTISIG_PROPOSER_PRIV_KEY not set in environment')
}

const safeAddress = getAddress(process.env.CURATOR_MULTISIG_ADDRESS as Address)

interface ArkConfig {
  chain: string
  fleetAsset: string
  fleetAddress: string
  arkAddress: string
  fleetCap: string
  FleetMinimumBuffer: string
  ark: string
  arkSymbol: string
  arkMaxCap: string
  arkMaxPercTVL: string
  arkMaxInflow: string
  arkMaxOutflow: string
  reallocInterval: string
  deployedBySummerFi: string
  WhiteListedByBA: string
}

// Add new interface for auction config
interface AuctionConfig {
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  prices: {
    [key in Token]: number
  }
  duration: string
  kickerRewardPercentage: number
  decayType: string
  maxMultiplier: number
  minMultiplier: number
}
const spkArkAddresses = [
  '0xC9dd080C9ecCFcdbf379714D84CdC8Bd01046AE1',
  '0xDB6d68d571FbEF7D67827844DD800884EA9cc02E',
  '0xCCBd61b6c2fB58Da5bbD8937Ca25164eF29c1cc4',
  '0x165D1accC5C6326e7EE4deeF75Ac3ffC8ce4D79B',
  '0x78f466314b2A69685e464431eDF7688cB77De131',
  '0x1Ae10e9425653177282E6054a5c828391a533aC7',
  '0x8948a5F3D24F7A6d50FF36064e8cff33B2aF062f',
  '0x9890C99f504337C3500AC05c267c38dfcd41C3e2',
  '0xf8Db64D39D1c7382fE47De8B72435c7e9DFB2894',
  '0x6A60336bc45aE0C9aabAe13acc4bcc0cbd962e44',
  '0x26c50781f592Cf4c7389615A38Dc927C81F8a0a4',
  '0xf28b3262E2bB0F11eD25A4c4dC87f7F33DD1b5c5',
  '0x650012Ba5369d051e381435e8161454C1A0fcbdc',
  '0x570957bC84b5607e2412dE72461FbbD02844b042',
].map((address) => address.toLowerCase())
async function loadConfigurations() {
  const response = await prompts({
    type: 'select',
    name: 'source',
    message: 'Select configuration source',
    choices: [
      { title: 'Public (Main Location)', value: 'public' },
      { title: 'Institution', value: 'institution' },
    ],
  })

  let arksConfigPath
  let auctionsConfigPath
  let institutionId: string | undefined

  if (response.source === 'institution') {
    const institutionsDir = path.join(__dirname, '../../config/institutions')
    const institutions = fs.readdirSync(institutionsDir).filter((file) => {
      return fs.statSync(path.join(institutionsDir, file)).isDirectory()
    })

    const institutionResponse = await prompts({
      type: 'select',
      name: 'institution',
      message: 'Select institution',
      choices: institutions.map((inst) => ({ title: inst, value: inst })),
    })

    const institution = institutionResponse.institution
    if (!institution) {
      console.error('No institution selected')
      process.exit(1)
    }

    institutionId = institution
    arksConfigPath = path.join(institutionsDir, institution, 'curation/arks.json')
    auctionsConfigPath = path.join(institutionsDir, institution, 'curation/auctions.json')
  } else {
    arksConfigPath = path.join(__dirname, '../../config/curation/arks.json')
    auctionsConfigPath = path.join(__dirname, '../../config/curation/auctions.json')
  }

  console.log(`Loading configuration from:`)
  console.log(`- Arks: ${arksConfigPath}`)
  console.log(`- Auctions: ${auctionsConfigPath}`)

  const arksConfig: ArkConfig[] = JSON.parse(fs.readFileSync(arksConfigPath, 'utf-8'))

  const auctionsConfig: AuctionConfig[] = JSON.parse(fs.readFileSync(auctionsConfigPath, 'utf-8'))

  const modeResponse = await prompts({
    type: 'select',
    name: 'mode',
    message: 'Select update mode',
    choices: [
      { title: 'Auctions Only', value: 'auctions_only' },
      { title: 'Full Update (Auctions + Ark/Fleet Params)', value: 'all' },
    ],
  })

  return {
    arksConfig,
    auctionsConfig,
    source: response.source,
    mode: modeResponse.mode,
    institutionId,
  }
}

function parseTimeString(timeStr: string): number {
  const unit = timeStr.slice(-1)
  const value = parseInt(timeStr.slice(0, -1))

  switch (unit) {
    case 'd':
      return value * 86400 // days to seconds
    case 'h':
      return value * 3600
    case 'm':
      return value * 60
    case 's':
      return value
    default:
      throw new Error(`Invalid time unit: ${unit}`)
  }
}

const WAD = BigInt(1e18)
const SIX_DECIMALS = 6n
const EIGHTEEN_DECIMALS = 18n

function getAssetDecimals(assetSymbol: string): bigint {
  switch (assetSymbol.toLowerCase()) {
    case 'weth':
    case 'reul':
    case 'ws':
    case 'seam':
    case 'syrup':
    case 'well':
    case 'silo':
    case 'xsilo':
    case 'comp':
    case 'spk':
    case 'usdf':
    case 'extra':
    case 'asonws':
    case 'fluid':
      return EIGHTEEN_DECIMALS
    case 'usdc':
    case 'usdce':
    case 'usdt':
    case 'eurc':
      return SIX_DECIMALS
    default:
      throw new Error(`Unknown asset symbol: ${assetSymbol}`)
  }
}

function parseAmount(amountValue: string | number, assetSymbol: string): bigint {
  const decimals = getAssetDecimals(assetSymbol)

  // If it's already a number, convert directly
  if (typeof amountValue === 'number') {
    if (amountValue < 1) {
      return BigInt(Math.floor(amountValue * Math.pow(10, Number(decimals))))
    }
    return BigInt(amountValue) * BigInt(Math.pow(10, Number(decimals)))
  }
  // If it's a string, remove commas first and multiply by decimals
  const baseAmount = BigInt(amountValue.replace(/,/g, ''))
  return baseAmount * BigInt(Math.pow(10, Number(decimals)))
}

/**
 *
 * @param percentValue Lazy Summer contracts use `Percentage` library where 1% == 1 WAD (1e18)
 * @returns
 */
function parsePercentage(percentValue: string | number): bigint {
  // If it's already a number (e.g. 0.37), handle floating point precision issues
  if (typeof percentValue === 'number') {
    // Round to 1 decimal place to handle floating point precision issues
    // For 0.39299999999999996, this gives us 39.3 instead of 39
    const roundedPercent = Math.round(percentValue * 1000)
    return (BigInt(roundedPercent) * WAD) / 10n
  }
  // If it's a string with % (legacy format), convert to percentage
  const percent = parseFloat(percentValue.replace('%', ''))
  return BigInt(percent) * WAD
}

// Update the multiplier calculation to handle decimals correctly
function calculateAuctionMultipliers(
  basePrice: number,
  assetDecimals: bigint,
  maxMultiplier: number,
  minMultiplier: number,
): { startPrice: bigint; endPrice: bigint } {
  // Convert base price to asset decimals
  const baseWithDecimals = BigInt(Math.round(basePrice * Math.pow(10, Number(assetDecimals))))
  const multiplierBase = 1000
  const maxMultiplierBase = Math.round(maxMultiplier * multiplierBase)
  const minMultiplierBase = Math.round(minMultiplier * multiplierBase)
  // Start at 2x price and end at 0.1x price
  const startPrice = (baseWithDecimals * BigInt(maxMultiplierBase)) / BigInt(multiplierBase)
  const endPrice = (baseWithDecimals * BigInt(minMultiplierBase)) / BigInt(multiplierBase)

  return { startPrice, endPrice }
}
const rewardsConfig: Record<string, Record<string, Token[]>> = {
  mainnet: {
    'sky-rewards': [Token.SKY, Token.SPK],
    morpho: [Token.MORPHO],
    euler: [Token.REUL, Token.SPK],
    gearbox: [Token.GEAR, Token.SPK, Token.USDF],
    siloV2: [Token.SILO, Token.XSILO, Token.SPK],
    compound_v3: [Token.COMP, Token.SPK],
    maple: [Token.SYRUP],
    fluid: [Token.SPK, Token.FLUID],
    spark: [Token.SPK],
    sky: [Token.SPK],
    aave_v3: [Token.SPK],
  },
  base: {
    morpho: [Token.MORPHO, Token.WELL, Token.SEAM, Token.EXTRA],
    euler: [Token.REUL],
    moonwell: [Token.WELL],
    compound_v3: [Token.COMP],
    fluid: [Token.FLUID],
  },
  sonic: {
    aave_v3: [Token.WS, Token.ASONWS],
    euler: [Token.WS],
    siloV2: [Token.WS, Token.SILO, Token.XSILO],
  },
  arbitrum: {
    compound_v3: [Token.COMP],
    fluid: [Token.ARB, Token.FLUID],
    siloV2: [Token.ARB],
    morpho: [Token.ARB, Token.MORPHO],
  },
}

// Custom function to read fleet config without hre
async function readFleetConfig(
  fleetAddress: Address,
  chain: SupportedChain,
  isInstitution: boolean,
) {
  const publicClient = createPublicClient({
    chain: VIEM_CHAIN_MAP[chain],
    transport: http(RPC_URL_MAP[chain]),
  })

  const config = (await publicClient.readContract({
    address: fleetAddress,
    abi: FLEET_COMMANDER_ABI,
    functionName: 'getConfig',
  })) as bigint[]

  let rebalanceCooldown = 0n
  if (!isInstitution) {
    rebalanceCooldown = (await publicClient.readContract({
      address: fleetAddress,
      abi: FLEET_COMMANDER_ABI,
      functionName: 'getCooldown',
    })) as bigint
  }

  return {
    depositCap: BigInt(config[2]),
    minimumBufferBalance: BigInt(config[1]),
    rebalanceCooldown: Number(rebalanceCooldown),
  }
}

// Custom function to read ark config without hre
async function readArkConfig(arkAddress: Address, chain: SupportedChain) {
  const publicClient = createPublicClient({
    chain: VIEM_CHAIN_MAP[chain],
    transport: http(RPC_URL_MAP[chain]),
  })

  const [depositCap, maxDepositPercentageOfTVL, maxRebalanceInflow, maxRebalanceOutflow] =
    await Promise.all([
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'depositCap',
      }),
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'maxDepositPercentageOfTVL',
      }),
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'maxRebalanceInflow',
      }),
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'maxRebalanceOutflow',
      }),
    ])

  return {
    depositCap: BigInt(depositCap as bigint),
    maxDepositPercentageOfTVL: BigInt(maxDepositPercentageOfTVL as bigint),
    maxRebalanceInflow: BigInt(maxRebalanceInflow as bigint),
    maxRebalanceOutflow: BigInt(maxRebalanceOutflow as bigint),
  }
}

async function createAuctionConfigurationTransaction(
  arkConfig: ArkConfig,
  auctionsConfig: AuctionConfig[],
  chain: SupportedChain,
  raftAddress: `0x${string}`,
): Promise<TransactionBase[] | null> {
  // Only configure auction parameters for Morpho and Euler arks
  if (!rewardsConfig[chain] || !rewardsConfig[chain][arkConfig.ark]) {
    return null
  }
  const transactions: TransactionBase[] = []
  // Determine reward token based on ark type
  const rewardTokenSymbols = rewardsConfig[chain][arkConfig.ark]
  for (const rewardTokenSymbol of rewardTokenSymbols) {
    const txes = await handleSingleRewardToken(
      rewardTokenSymbol,
      auctionsConfig,
      chain,
      arkConfig,
      raftAddress,
    )
    if (txes && txes.length > 0) {
      transactions.push(...txes)
    }
  }
  return transactions
}
/**
 * Gets the raft address for a given chain, using institution config if applicable
 */
function getRaftAddress(
  chain: SupportedChain,
  isInstitution: boolean,
  institutionId?: string,
): `0x${string}` {
  if (isInstitution && institutionId) {
    const institutionConfig = readInstitutionConfigFile(institutionId, false)
    const chainConfig = institutionConfig[chain]
    const raftAddress = chainConfig?.deployedContracts?.core?.raft?.address
    if (!raftAddress) {
      throw new Error(
        `No raft address found in institution config for ${institutionId} on chain ${chain}`,
      )
    }
    return raftAddress as `0x${string}`
  }
  return addresses[chain].raft as `0x${string}`
}

async function handleSingleRewardToken(
  rewardTokenSymbol: string,
  auctionsConfig: AuctionConfig[],
  chain: SupportedChain,
  arkConfig: ArkConfig,
  raftAddress: `0x${string}`,
) {
  if (
    rewardTokenSymbol === 'spk' &&
    !spkArkAddresses.includes(arkConfig.arkAddress.toLowerCase())
  ) {
    console.log(
      `Skipping ${rewardTokenSymbol.toUpperCase()} for ${arkConfig.arkSymbol} as it is a SPK ark`,
    )
    return []
  }
  if (rewardTokenSymbol === 'extra' && !arkConfig.arkSymbol.includes('extrafi')) {
    console.log(
      `Skipping ${rewardTokenSymbol.toUpperCase()} for ${arkConfig.arkSymbol} as it is a EXTRA ark`,
    )
    return []
  }
  if (rewardTokenSymbol === 'well' && !arkConfig.arkSymbol.includes('moonwell')) {
    console.log(
      `Skipping ${rewardTokenSymbol.toUpperCase()} for ${arkConfig.arkSymbol} as it does not support moonwell`,
    )
    return []
  }
  if (rewardTokenSymbol === 'seam' && !arkConfig.arkSymbol.includes('seam')) {
    console.log(
      `Skipping ${rewardTokenSymbol.toUpperCase()} for ${arkConfig.arkSymbol} as it does not support seam`,
    )
    return []
  }
  // if (rewardTokenSymbol === 'syrup' && !arkConfig.arkSymbol.includes('usdc')) {
  //   console.log(
  //     `Skipping ${rewardTokenSymbol.toUpperCase()} for ${arkConfig.arkSymbol} as it does not support usdc`,
  //   )
  //   return []
  // }
  // Find matching auction config
  const auctionConfig = auctionsConfig.find(
    (config) => config.rewardTokenSymbol.toLowerCase() === rewardTokenSymbol,
  )

  if (!auctionConfig) {
    throw new Error(`No auction configuration found for ${rewardTokenSymbol.toUpperCase()}`)
  }

  // Get base price for the fleet's asset
  const assetKey = arkConfig.fleetAsset.toLowerCase() as Token
  const basePrice = auctionConfig.prices[assetKey]
  if (basePrice === undefined) {
    throw new Error(
      `No price configuration found for asset ${assetKey} in ${rewardTokenSymbol.toUpperCase()} auctions`,
    )
  }

  const assetDecimals = getAssetDecimals(arkConfig.fleetAsset)
  const { startPrice, endPrice } = calculateAuctionMultipliers(
    basePrice,
    assetDecimals,
    auctionConfig.maxMultiplier,
    auctionConfig.minMultiplier,
  )
  const duration = parseTimeString(auctionConfig.duration)
  const kickerRewardPercentage = parsePercentage(auctionConfig.kickerRewardPercentage)
  const decayType = auctionConfig.decayType === 'linear' ? 0 : 1

  // Get current auction parameters
  const rewardTokenAddress = addresses[chain].tokens[rewardTokenSymbol.toLowerCase() as Token]
  if (!rewardTokenAddress || rewardTokenAddress === '0x0000000000000000000000000000000000000000') {
    throw new Error(`No reward token address found for ${auctionConfig.rewardTokenSymbol}`)
  }

  const publicClient = createPublicClient({
    chain: VIEM_CHAIN_MAP[chain],
    transport: http(RPC_URL_MAP[chain]),
  })

  const isWhitelistedInRaft = (await publicClient.readContract({
    address: raftAddress,
    abi: RAFT_ABI,
    functionName: 'sweepableTokens',
    args: [arkConfig.arkAddress, rewardTokenAddress],
  })) as boolean

  const currentAuctionParams = (await publicClient.readContract({
    address: raftAddress,
    abi: RAFT_ABI,
    functionName: 'arkAuctionParameters',
    args: [arkConfig.arkAddress, rewardTokenAddress],
  })) as [bigint, bigint, bigint, bigint, bigint]

  const currentDuration = currentAuctionParams[0]
  const currentStartPrice = currentAuctionParams[1]
  const currentEndPrice = currentAuctionParams[2]
  const currentKickerRewardPercentage = currentAuctionParams[3]
  const currentDecayType = currentAuctionParams[4]

  logValueComparison('Duration', currentDuration, duration, arkConfig.arkSymbol, ' seconds')
  logValueComparison(
    'Start price',
    currentStartPrice,
    startPrice,
    arkConfig.arkSymbol,
    ` ${arkConfig.fleetAsset}`,
  )
  logValueComparison(
    'End price',
    currentEndPrice,
    endPrice,
    arkConfig.arkSymbol,
    ` ${arkConfig.fleetAsset}`,
  )
  logValueComparison(
    'Kicker reward',
    currentKickerRewardPercentage,
    kickerRewardPercentage,
    arkConfig.arkSymbol,
    ' %',
  )
  logValueComparison('Decay type', currentDecayType, decayType, arkConfig.arkSymbol)

  const txes: TransactionBase[] = []
  // Only update if any parameter has changed
  if (
    BigInt(duration) != currentDuration ||
    startPrice !== currentStartPrice ||
    endPrice !== currentEndPrice ||
    kickerRewardPercentage !== currentKickerRewardPercentage ||
    decayType !== Number(currentDecayType)
  ) {
    const setAuctionParamsCalldata = encodeFunctionData({
      abi: RAFT_ABI,
      functionName: 'setArkAuctionParameters',
      args: [
        arkConfig.arkAddress,
        rewardTokenAddress,
        {
          duration,
          startPrice,
          endPrice,
          kickerRewardPercentage,
          decayType,
        },
      ],
    })

    console.log('📝 Auction parameters update transaction created')
    txes.push({
      to: raftAddress,
      data: setAuctionParamsCalldata,
      value: '0',
    })
  }
  if (!isWhitelistedInRaft) {
    console.log('📝 Adding sweepable token transaction')
    console.log(`Setting ${arkConfig.arkAddress} to sweepable for ${rewardTokenAddress}`)
    const setSweepableTokenCalldata = encodeFunctionData({
      abi: RAFT_ABI,
      functionName: 'setSweepableToken',
      args: [arkConfig.arkAddress, rewardTokenAddress, true],
    })
    txes.push({
      to: raftAddress,
      data: setSweepableTokenCalldata,
      value: '0',
    })
  }
  return txes
}
async function createConfigurationTransactions(
  arkConfig: ArkConfig,
  auctionsConfig: AuctionConfig[],
  chain: SupportedChain,
  isFirstArkForFleet: boolean,
  isInstitution: boolean,
  updateMode: 'auctions_only' | 'all',
  raftAddress: `0x${string}`,
): Promise<TransactionBase[]> {
  const transactions: TransactionBase[] = []

  // Only set fleet-wide parameters once per fleet
  if (isFirstArkForFleet && updateMode === 'all') {
    console.log(`\n📊 Reading current fleet configuration...`)
    const currentFleetConfig = await readFleetConfig(
      arkConfig.fleetAddress as Address,
      chain,
      isInstitution,
    )

    console.log(`\n🔄 Fleet-wide parameters for ${arkConfig.fleetAddress}:`)

    // Set fleet deposit cap
    const fleetCap = parseAmount(arkConfig.fleetCap, arkConfig.fleetAsset)
    logValueComparison(
      'Fleet deposit cap',
      currentFleetConfig.depositCap,
      fleetCap,
      arkConfig.arkSymbol,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentFleetConfig.depositCap !== fleetCap) {
      const setFleetCapCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setFleetDepositCap',
        args: [fleetCap],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setFleetCapCalldata,
        value: '0',
      })
    }

    // Set minimum buffer balance
    const minBuffer = parseAmount(arkConfig.FleetMinimumBuffer, arkConfig.fleetAsset)
    logValueComparison(
      'Minimum buffer balance',
      currentFleetConfig.minimumBufferBalance,
      minBuffer,
      arkConfig.arkSymbol,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentFleetConfig.minimumBufferBalance !== minBuffer) {
      const setMinBufferCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setMinimumBufferBalance',
        args: [minBuffer],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setMinBufferCalldata,
        value: '0',
      })
    }

    // Update rebalance cooldown
    if (!isInstitution) {
      const cooldown = parseTimeString(arkConfig.reallocInterval)
      logValueComparison(
        'Rebalance cooldown',
        currentFleetConfig.rebalanceCooldown,
        cooldown,
        arkConfig.arkSymbol,
        ' seconds',
      )
      if (currentFleetConfig.rebalanceCooldown !== cooldown) {
        const setCooldownCalldata = encodeFunctionData({
          abi: FLEET_COMMANDER_ABI,
          functionName: 'updateRebalanceCooldown',
          args: [cooldown],
        })
        transactions.push({
          to: arkConfig.fleetAddress,
          data: setCooldownCalldata,
          value: '0',
        })
      }
    }
  }

  // Handle auction configuration
  const auctionTransactions = await createAuctionConfigurationTransaction(
    arkConfig,
    auctionsConfig,
    chain,
    raftAddress,
  )

  if (auctionTransactions && auctionTransactions.length > 0) {
    transactions.push(...auctionTransactions)
  }

  if (updateMode === 'all') {
    // Configure ark parameters
    const arkAddress = arkConfig.arkAddress
    console.log(
      `\n📊 Reading current ark configuration for ${arkConfig.arkSymbol} ${arkAddress}...`,
    )
    const currentArkConfig = await readArkConfig(arkAddress as Address, chain)

    // Set ark deposit cap
    const arkCap = parseAmount(arkConfig.arkMaxCap, arkConfig.fleetAsset)

    logValueComparison(
      'Ark deposit cap',
      currentArkConfig.depositCap,
      arkCap,
      arkConfig.arkSymbol,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentArkConfig.depositCap !== arkCap) {
      const setArkCapCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setArkDepositCap',
        args: [arkAddress, arkCap],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setArkCapCalldata,
        value: '0',
      })
    }

    // Set ark max deposit percentage of TVL
    const maxPercTVL = parsePercentage(arkConfig.arkMaxPercTVL)
    logPercentageComparison(
      'Ark max TVL percentage',
      currentArkConfig.maxDepositPercentageOfTVL,
      maxPercTVL,
      WAD,
    )
    if (currentArkConfig.maxDepositPercentageOfTVL !== maxPercTVL) {
      const setMaxPercTVLCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setArkMaxDepositPercentageOfTVL',
        args: [arkAddress, maxPercTVL],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setMaxPercTVLCalldata,
        value: '0',
      })
    }

    // Set ark max rebalance inflow/outflow
    const maxInflow = parseAmount(arkConfig.arkMaxInflow, arkConfig.fleetAsset)
    const maxOutflow = parseAmount(arkConfig.arkMaxOutflow, arkConfig.fleetAsset)

    logValueComparison(
      'Ark max inflow',
      currentArkConfig.maxRebalanceInflow,
      maxInflow,
      arkConfig.arkSymbol,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentArkConfig.maxRebalanceInflow !== maxInflow) {
      const setMaxInflowCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setArkMaxRebalanceInflow',
        args: [arkAddress, maxInflow],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setMaxInflowCalldata,
        value: '0',
      })
    }

    logValueComparison(
      'Ark max outflow',
      currentArkConfig.maxRebalanceOutflow,
      maxOutflow,
      arkConfig.arkSymbol,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentArkConfig.maxRebalanceOutflow !== maxOutflow) {
      const setMaxOutflowCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setArkMaxRebalanceOutflow',
        args: [arkAddress, maxOutflow],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setMaxOutflowCalldata,
        value: '0',
      })
    }
  }

  return transactions
}

async function main() {
  console.log('🚀 Starting fleet configuration update process...\n')

  // Load configurations
  const {
    arksConfig: allArksConfig,
    auctionsConfig,
    source,
    mode,
    institutionId,
  } = await loadConfigurations()
  const isInstitution = source === 'institution'
  const updateMode = mode as 'auctions_only' | 'all'

  // Process each chain
  for (const chain of SUPPORTED_CHAINS) {
    console.log(`\n🔗 Processing chain: ${chain}`)

    const chainConfig = {
      chain: VIEM_CHAIN_MAP[chain],
      chainId: VIEM_CHAIN_MAP[chain].id,
      rpcUrl: RPC_URL_MAP[chain],
    }

    // Filter arks for current chain
    const arksConfig = allArksConfig.filter((arkConfig) => {
      const isMatchingChain = arkConfig.chain.toLowerCase() === chain.toLowerCase()
      return isMatchingChain
    })

    if (arksConfig.length === 0) {
      console.log(`⚠️ No ark configurations found for chain ${chain}, skipping...`)
      continue
    }

    console.log(`\n📝 Found ${arksConfig.length} ark configurations for ${chain}`)

    // Get raft address for this chain
    const raftAddress = getRaftAddress(chain, isInstitution, institutionId)
    console.log(`📍 Using raft address: ${raftAddress}`)

    const transactions: TransactionBase[] = []
    const configuredFleets = new Set<string>()

    for (const arkConfig of arksConfig) {
      // Skip if no arkAddress is provided
      if (!arkConfig.arkAddress) {
        console.log(
          `⚠️ Skipping ark config without arkAddress for ${arkConfig.chain} ${arkConfig.fleetAsset}`,
        )
        continue
      }

      // Use fleet address as part of the unique key
      const fleetKey = `${arkConfig.chain.toLowerCase()}_${arkConfig.fleetAddress.toLowerCase()}`
      const isFirstArkForFleet = !configuredFleets.has(fleetKey)

      if (isFirstArkForFleet) {
        console.log(
          `\n📝 Configuring new fleet ${arkConfig.fleetAddress} ` +
            `(${arkConfig.fleetAddress}) on ${arkConfig.chain}...`,
        )
        configuredFleets.add(fleetKey)
      }

      const fleetTransactions = await createConfigurationTransactions(
        arkConfig,
        auctionsConfig,
        chain,
        isFirstArkForFleet,
        isInstitution,
        updateMode,
        raftAddress,
      )
      transactions.push(...fleetTransactions)
    }

    console.log(`\n🔧 Created ${transactions.length} configuration transactions for ${chain}`)

    if (transactions.length > 0) {
      // Create Safe transaction JSON for this chain
      const safeTransactionsJson = {
        version: '1.0',
        chainId: chainConfig.chainId.toString(),
        createdAt: Date.now(),
        meta: {
          name: `Fleet Configuration Update - ${chain}`,
          description: 'Update fleet and ark configurations',
          txBuilderVersion: '1.18.0',
          createdFromSafeAddress: safeAddress,
          createdFromOwnerAddress: '',
          checksum: '',
        },
        transactions: transactions.map((tx) => ({
          to: tx.to,
          value: tx.value || '0',
          data: tx.data,
          contractMethod: null,
          contractInputsValues: null,
        })),
      }

      // Write to file
      const outputPath = path.join(
        __dirname,
        `../../proposals/curation/safe-transactions-${chain}-${Date.now()}.json`,
      )
      fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))
      console.log(`\n✅ Saved transactions to ${outputPath}`)
    } else {
      console.log(`\n⚠️ No transactions needed for ${chain}`)
    }
  }
}
const MAX_UINT256 = BigInt(
  '115792089237316195423570985008687907853269984665640564039457584007913129639935',
)
function formatValue(value: bigint | number, unit: string): string {
  // Handle max uint
  if (typeof value === 'bigint' && value === MAX_UINT256) {
    return 'max uint (no limit)'
  }

  // Handle decimals for known assets
  if (unit.trim() === 'USDC' || unit.trim() === 'USDT') {
    if (typeof value === 'bigint') {
      const formatted = Number(value) / 1e6
      return `${value.toString()} (${formatted.toLocaleString()})`
    }
  }

  if (unit.trim() === 'WETH') {
    if (typeof value === 'bigint') {
      const formatted = Number(value) / 1e18
      return `${value.toString()} (${formatted.toLocaleString()})`
    }
  }

  // Default formatting for other values
  return value.toString()
}
export function logValueComparison(
  label: string,
  currentValue: bigint | number,
  newValue: bigint | number,
  name: string,
  unit: string = '',
): void {
  const hasChanged = currentValue != newValue
  const color = hasChanged ? chalk.red : chalk.green
  const arrow = hasChanged ? '→' : '='

  const formattedCurrent = formatValue(currentValue, unit)
  const formattedNew = formatValue(newValue, unit)
  if (hasChanged) {
    console.log(
      color(
        `${name} - ${label.padEnd(30)} ${formattedCurrent}${unit} ${arrow} ${formattedNew}${unit} ${
          hasChanged ? ' (updating)' : ' (unchanged)'
        }`,
      ),
    )
  }
}

export function logPercentageComparison(
  label: string,
  currentValue: bigint,
  newValue: bigint,
  WAD: bigint,
): void {
  const hasChanged = currentValue !== newValue
  const color = hasChanged ? chalk.red : chalk.green
  const arrow = hasChanged ? '→' : '='
  const currentPercent = Number(currentValue) / Number(WAD)
  const newPercent = Number(newValue) / Number(WAD)
  if (hasChanged) {
    console.log(
      color(
        `${label.padEnd(30)} ${currentPercent}% ${arrow} ${newPercent}%${
          hasChanged ? ' (updating)' : ' (unchanged)'
        }`,
      ),
    )
  }
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
