import { GetParameterCommand, SSMClient } from '@aws-sdk/client-ssm'

let ssmClient: SSMClient | null = null
const secretCache: Record<string, string> = {}

export async function getSecret(name: string): Promise<string> {
  // 1. Check process.env first (for local dev)
  if (process.env[name]) {
    return process.env[name]
  }

  // 2. Check in-memory cache
  if (secretCache[name]) {
    return secretCache[name]
  }

  // 3. Fallback to SSM if running in AWS
  const appId = process.env.AWS_APP_ID
  const branch = process.env.AWS_BRANCH
  const region = process.env.REGION || 'eu-central-1'

  if (!appId || !branch) {
    throw new Error(`Discovery failed: AWS_APP_ID or AWS_BRANCH is missing in environment.`)
  }

  if (!ssmClient) {
    ssmClient = new SSMClient({ region })
  }

  const branchPath = `/amplify/${appId}/${branch}/${name}`
  const mainPath = `/amplify/${appId}/main/${name}`

  let lastError: any = null

  try {
    // Try the branch-specific secret first
    const command = new GetParameterCommand({
      Name: branchPath,
      WithDecryption: true,
    })
    const response = await ssmClient.send(command)
    const value = response.Parameter?.Value

    if (value) {
      secretCache[name] = value
      return value
    }
  } catch (error: any) {
    lastError = error
    // If branch secret not found, fallback to main
    if (error.name === 'ParameterNotFound' && branch !== 'main') {
      try {
        const fallbackCommand = new GetParameterCommand({
          Name: mainPath,
          WithDecryption: true,
        })
        const fallbackResponse = await ssmClient.send(fallbackCommand)
        const fallbackValue = fallbackResponse.Parameter?.Value
        if (fallbackValue) {
          secretCache[name] = fallbackValue
          return fallbackValue
        }
      } catch (fallbackError: any) {
        lastError = fallbackError
      }
    }
  }

  // If we reach here, both attempts failed or errored out
  const errorMessage =
    lastError?.message || `Secret ${name} not found in SSM at ${branchPath} or ${mainPath}`
  const errorName = lastError?.name || 'SecretNotFound'

  const finalError = new Error(errorMessage)
  finalError.name = errorName
  throw finalError
}
