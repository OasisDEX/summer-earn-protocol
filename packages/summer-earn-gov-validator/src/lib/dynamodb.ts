import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb'

const getConfig = () => {
  const region = process.env.AWS_REGION || 'eu-central-1'
  const tableName = process.env.DYNAMODB_TABLE_NAME || 'SummerGovernanceCache'
  return { region, tableName }
}

function getClient() {
  const { region, tableName } = getConfig()
  const client = new DynamoDBClient({ region })
  return {
    docClient: DynamoDBDocumentClient.from(client, {
      marshallOptions: {
        removeUndefinedValues: true,
      },
    }),
    tableName,
  }
}

export async function getCache<T>(pk: string, sk: string): Promise<T | null> {
  const { docClient, tableName } = getClient()

  if (!tableName) {
    console.error('❌ DynamoDB Error: Table name is undefined. Check your .env.local')
    return null
  }

  try {
    const { Item } = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: { PK: pk, SK: sk },
      }),
    )
    return Item as T
  } catch (error) {
    console.error(`❌ DynamoDB Get Error [${tableName}]:`, error)
    console.error('Params:', { PK: pk, SK: sk })
    return null
  }
}

export async function putCache(
  pk: string,
  sk: string,
  data: Record<string, unknown>,
): Promise<boolean> {
  const { docClient, tableName } = getClient()

  if (!tableName) {
    console.error('❌ DynamoDB Error: Table name is undefined. Check your .env.local')
    return false
  }

  try {
    await docClient.send(
      new PutCommand({
        TableName: tableName,
        Item: {
          PK: pk,
          SK: sk,
          ...data,
          updatedAt: new Date().toISOString(),
        },
      }),
    )
    return true
  } catch (error) {
    console.error(`❌ DynamoDB Put Error [${tableName}]:`, error)
    console.error('Params:', { PK: pk, SK: sk })
    return false
  }
}
