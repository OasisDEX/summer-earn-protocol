import prompts from 'prompts'
import { continueDeploymentCheck } from './prompt-helpers'

/**
 * Handles the retrieval and confirmation of the DEPLOYMENT_ID.
 * If DEPLOYMENT_ID is provided in the environment, it asks for user confirmation.
 * If not provided, it prompts the user to enter a DEPLOYMENT_ID.
 *
 * @param {number} chainId The chain id for the deployment
 *
 * @returns {Promise<string>} The confirmed or entered DEPLOYMENT_ID
 * @throws {Error} If the user cancels the confirmation or input process
 */
export async function handleDeploymentId(chainId: number): Promise<string> {
  let deploymentId = process.env.DEPLOYMENT_ID

  if (deploymentId) {
    const confirmed = await continueDeploymentCheck(
      `DEPLOYMENT_ID found: ${deploymentId}. Do you want to use this ID?`,
    )

    if (!confirmed) {
      deploymentId = undefined // Reset deploymentId if not confirmed
    }
  }

  if (!deploymentId) {
    const { id } = await prompts({
      type: 'text',
      name: 'id',
      message: 'Please enter a DEPLOYMENT_ID:',
      initial: `chain-${chainId}`,
      validate: (value) => value.length > 0 || 'DEPLOYMENT_ID cannot be empty',
    })

    if (!id) {
      throw new Error('DEPLOYMENT_ID input cancelled by user')
    }

    return id
  }

  throw new Error('No deployment ID resolved')
}
