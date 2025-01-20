/**
 * Generates a deployment ID based on the chain ID.
 * @param {number} chainId - The chain ID for the deployment.
 * @returns {string} The generated deployment ID.
 */
export async function handleDeploymentId(chainId: number): Promise<string> {
  return `chain-${chainId}`
}
