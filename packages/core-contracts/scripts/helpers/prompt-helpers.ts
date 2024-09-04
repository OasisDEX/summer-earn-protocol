import prompts from 'prompts'

export async function continueDeploymentCheck(message?: string) {
  const _message = message ?? 'Do you want to continue with the deployment?'

  const { confirmed } = await prompts({
    type: 'toggle',
    name: 'confirmed',
    initial: true,
    active: 'yes',
    inactive: 'no',
    message: _message,
  })

  return confirmed
}
