import fs from 'node:fs'
import path from 'node:path'
import kleur from 'kleur'
import { Address, Hex } from 'viem'

export type GovernorAction = {
  description: string
  to: Address
  data: Hex
  value: bigint
}

type SafeTx = {
  to: Address
  value: string
  data: Hex
  contractMethod: null
  contractInputsValues: null
}

export type SafeBatch = {
  version: '1.0'
  chainId: string
  createdAt: number
  meta: {
    name: string
    description: string
    txBuilderVersion: '1.16.5'
    createdFromSafeAddress: string
    createdFromOwnerAddress: string
    checksum: string
  }
  transactions: SafeTx[]
}

/**
 * Collects governor-gated actions during a deploy run. Either executes each one
 * on-chain (if the deployer has the right role) or accumulates them so the
 * caller can emit a Safe Transaction Builder JSON file at the end.
 *
 * Nothing is submitted to Safe automatically — the file is meant to be
 * imported manually via Safe UI → Apps → Transaction Builder → Load.
 */
export class GovernorActionBatch {
  private pending: GovernorAction[] = []

  constructor(
    public readonly hasRole: boolean,
    public readonly hre: any,
    private readonly batchName: string = 'Governor actions',
  ) {}

  async runOrQueue(action: GovernorAction): Promise<void> {
    if (this.hasRole) {
      const publicClient = await this.hre.viem.getPublicClient()
      const [wallet] = await this.hre.viem.getWalletClients()
      const hash = await wallet.sendTransaction({
        to: action.to,
        data: action.data,
        value: action.value,
      })
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`✓ ${action.description}`))
    } else {
      this.pending.push(action)
      console.log(kleur.yellow(`⊳ captured for Safe: ${action.description}`))
    }
  }

  /**
   * Force the action onto the Safe batch regardless of `hasRole`. Use when
   * the action is gated by an authority other than the role this batch was
   * constructed for (e.g. an Ownable owner on a different contract).
   */
  enqueue(action: GovernorAction): void {
    this.pending.push(action)
    console.log(kleur.yellow(`⊳ captured for Safe: ${action.description}`))
  }

  getPending(): GovernorAction[] {
    return this.pending.slice()
  }

  /**
   * Write a Safe Transaction Builder JSON file. Returns the absolute output
   * path, or null when the batch is empty (no file produced).
   */
  async writeSafeBatch(outFile: string, chainId: number): Promise<string | null> {
    if (this.pending.length === 0) return null

    const abs = path.isAbsolute(outFile) ? outFile : path.resolve(outFile)
    fs.mkdirSync(path.dirname(abs), { recursive: true })

    const batch: SafeBatch = {
      version: '1.0',
      chainId: chainId.toString(),
      createdAt: Date.now(),
      meta: {
        name: this.batchName,
        description: 'Governor actions captured by a deploy script',
        txBuilderVersion: '1.16.5',
        createdFromSafeAddress: '',
        createdFromOwnerAddress: '',
        checksum: '',
      },
      transactions: this.pending.map((p) => ({
        to: p.to,
        value: p.value.toString(),
        data: p.data,
        contractMethod: null,
        contractInputsValues: null,
      })),
    }

    fs.writeFileSync(abs, JSON.stringify(batch, null, 2) + '\n', 'utf8')
    return abs
  }
}
