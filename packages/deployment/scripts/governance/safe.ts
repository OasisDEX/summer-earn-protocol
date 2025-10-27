import SafeApiKit from '@safe-global/api-kit'
import Safe from '@safe-global/protocol-kit'
import { OperationType, TransactionBase } from '@safe-global/types-kit'
import { Address, getAddress } from 'viem'

async function proposeSafeTransactionBatch(
  protocolKit: Safe,
  apiKit: SafeApiKit,
  transactions: TransactionBase[],
  safeAddress: Address,
  deployer: Address,
  startNonce: number,
  batchIndex: number,
  batchSize: number,
): Promise<void> {
  const batchStart = batchIndex * batchSize
  const batchTransactions = transactions.slice(batchStart, batchStart + batchSize)

  if (batchTransactions.length === 0) return

  console.log(
    `\n📦 Proposing batch ${batchIndex + 1} with ${batchTransactions.length} transactions...`,
  )

  const safeTransaction = await protocolKit.createTransaction({
    transactions: batchTransactions.map((tx) => ({
      to: getAddress(tx.to),
      data: tx.data,
      value: tx.value,
      operation: OperationType.Call,
    })),
  })

  const safeTransactionDataWithNonce = {
    ...safeTransaction.data,
    nonce: startNonce + batchIndex,
  }

  const safeTransactionWithNonce = {
    ...safeTransaction,
    data: safeTransactionDataWithNonce,
  }

  const safeTxHash = await protocolKit.getTransactionHash(safeTransactionWithNonce)
  const signature = await protocolKit.signHash(safeTxHash)

  await apiKit.proposeTransaction({
    safeAddress,
    safeTransactionData: safeTransactionDataWithNonce,
    safeTxHash,
    senderAddress: deployer,
    senderSignature: signature.data,
  })

  console.log(`✅ Batch ${batchIndex + 1} proposed successfully`)
}

export async function proposeAllSafeTransactions(
  transactions: TransactionBase[],
  deployer: Address,
  safeAddress: Address,
  chainId: number,
  rpcUrl: string,
  signerKey: Address,
  batchSize: number = 30,
): Promise<void> {
  const apiKit = new SafeApiKit({
    chainId: BigInt(chainId),
  })
  const safe = await Safe.init({
    provider: rpcUrl,
    signer: signerKey,
    safeAddress: safeAddress,
  })

  const startNonce = await safe.getNonce()
  console.log(`Starting with nonce: ${startNonce}`)

  const totalBatches = Math.ceil(transactions.length / batchSize)

  console.log(
    `\n🚀 Proposing ${transactions.length} transactions in ${totalBatches} batches of ${batchSize}...`,
  )
  console.log(`Starting with nonce: ${startNonce}`)

  for (let i = 0; i < totalBatches; i++) {
    await proposeSafeTransactionBatch(
      safe,
      apiKit,
      transactions,
      safeAddress,
      deployer,
      startNonce,
      i,
      batchSize,
    )
  }

  console.log(`\n✨ All ${totalBatches} batches proposed successfully`)
}
