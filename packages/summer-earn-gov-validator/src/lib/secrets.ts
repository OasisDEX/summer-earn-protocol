import { GetParameterCommand, SSMClient } from '@aws-sdk/client-ssm'

let ssmClient: SSMClient | null = null
const secretCache: Record<string, string> = {}

export async function getSecret(name: string): Promise<string | undefined> {
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
    console.warn(`Attempted to fetch secret ${name} but AWS_APP_ID or AWS_BRANCH is missing.`)
    return undefined
  }

  if (!ssmClient) {
    ssmClient = new SSMClient({ region })
  }

  const parameterName = `/amplify/${appId}/${branch}/${name}`

  try {
    const command = new GetParameterCommand({
      Name: parameterName,
      WithDecryption: true,
    })
    const response = await ssmClient.send(command)
    const value = response.Parameter?.Value

    if (value) {
      secretCache[name] = value
      return value
    }
  } catch (error) {
    console.error(`Error fetching secret ${name} from SSM (${parameterName}):`, error)
  }

  return undefined
}
