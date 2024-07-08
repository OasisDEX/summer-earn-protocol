// spawnDevNet.js
const { exec } = require('child_process')
require('dotenv').config()

const spawnDevnet = () => {
  const templateSlug = process.env.TENDERLY_TEMPLATE_SLUG
  const projectSlug = process.env.TENDERLY_PROJECT_SLUG
  const account = process.env.TENDERLY_ACCOUNT
  const deployerAddress = process.env.DEPLOYER_ADDRESS
  const fundAmount = process.env.FUND_AMOUNT || '0xDE0B6B3A7640000'

  if (!templateSlug || !projectSlug || !account) {
    console.error(
      'Please set TENDERLY_TEMPLATE_SLUG, TENDERLY_PROJECT_SLUG and TENDERLY_ACCOUNT in your .env file',
    )
    process.exit(1)
  }

  const command = `tenderly devnet spawn-rpc --template ${templateSlug} --project ${projectSlug} --account ${account}`

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error executing command: ${error.message}`)
      return
    }
    if (stderr) {
      console.error(`stderr: ${stderr}`)
    }

    const newDevNetUrl = stderr.trim()

    const fundCommand = `curl ${newDevNetUrl} -X POST -H "Content-Type: application/json" -d '{
      "jsonrpc": "2.0",
      "method": "tenderly_setBalance",
      "params": [["${deployerAddress}"], "${fundAmount}"],
      "id": "1234"
    }'`

    exec(fundCommand, (fundError, fundStdout, fundStderr) => {
      if (fundError) {
        console.error(`Error funding deployer address: ${fundError.message}`)
        return
      }
      if (fundStderr) {
        console.error(`stderr: ${fundStderr}`)
      }

      // console.log(`Deployer address funded: ${fundStdout}`)

      // Output the environment variable assignment
      console.log(`TENDERLY_VIRTUAL_TESTNET_RPC_URL=${newDevNetUrl}`)
    })
  })
}

spawnDevnet()
