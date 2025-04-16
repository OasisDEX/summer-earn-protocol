/**
 * Helper function to prompt for SIP minor number
 */
export async function getSipMinorNumber(): Promise<number | undefined> {
  try {
    // Check if prompts package is available
    const prompts = require('prompts')

    const response = await prompts({
      type: 'number',
      name: 'value',
      message:
        'Enter the SIP minor number for this proposal (e.g., for SIP5.1 enter 1, leave empty for no minor number):',
      validate: (value) =>
        value === '' || (Number.isInteger(Number(value)) && Number(value) >= 0)
          ? true
          : 'Please enter a valid non-negative integer or leave empty',
    })

    return response.value === '' ? undefined : Number(response.value)
  } catch (error) {
    console.log(kleur.yellow('Could not prompt for SIP minor number, continuing without it.'))
    return undefined
  }
}
