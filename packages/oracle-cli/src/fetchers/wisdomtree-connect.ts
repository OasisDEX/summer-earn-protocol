import fs from 'fs/promises'
import path from 'path'
import { getWTConfig } from '../config'

interface TokenData {
  access_token: string
  expires_at: number // timestamp in ms
}

export class WisdomTreeConnect {
  private readonly baseUrl = 'https://app.wisdomtreeconnect.com'
  private readonly tokenUrl = 'https://app.wisdomtreeconnect.com/o/token/'
  private readonly tokenFilePath = path.resolve(process.cwd(), '.wt-token.json')
  private token: TokenData | null = null

  constructor() {}

  private async loadToken(): Promise<void> {
    try {
      const data = await fs.readFile(this.tokenFilePath, 'utf-8')
      this.token = JSON.parse(data)
    } catch {
      this.token = null
    }
  }

  private async saveToken(token: TokenData): Promise<void> {
    await fs.writeFile(this.tokenFilePath, JSON.stringify(token, null, 2))
    this.token = token
  }

  private async authenticate(): Promise<string> {
    const config = getWTConfig()
    const data = new URLSearchParams({
      grant_type: 'password',
      username: config.WT_LOGIN,
      password: config.WT_PASSWORD,
      client_id: config.WT_CLIENT,
      client_secret: config.WT_SECRET,
      scope: 'read',
    })

    const response = await fetch(this.tokenUrl, {
      method: 'POST',
      body: data,
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(`Failed to fetch access token: ${JSON.stringify(errorData)}`)
    }

    const result = (await response.json()) as { access_token: string; expires_in: number }
    const tokenData: TokenData = {
      access_token: result.access_token,
      expires_at: Date.now() + result.expires_in * 1000 - 60000, // 1 minute buffer
    }

    await this.saveToken(tokenData)
    return tokenData.access_token
  }

  public async getAccessToken(): Promise<string> {
    if (!this.token) {
      await this.loadToken()
    }

    if (this.token && this.token.expires_at > Date.now()) {
      return this.token.access_token
    }

    return this.authenticate()
  }

  public async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const accessToken = await this.getAccessToken()
    const url = `${this.baseUrl}${endpoint}`

    const response = await fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(`API Request failed (${endpoint}): ${JSON.stringify(errorData)}`)
    }

    return (await response.json()) as T
  }

  // API Endpoints

  /**
   * Retrieves open accruals.
   */
  public async getAccruals(organisationGuid?: string): Promise<any[]> {
    const endpoint = organisationGuid ? `/api/accruals/${organisationGuid}/` : '/api/accruals/'
    return this.request<any[]>(endpoint)
  }

  /**
   * Retrieves order details.
   */
  public async getOrder(orderReference: string): Promise<any> {
    return this.request<any>(`/api/orders/${orderReference}`)
  }

  /**
   * Retrieves all orders.
   */
  public async getAllOrders(): Promise<any[]> {
    return this.request<any[]>('/api/orders/all')
  }

  /**
   * Retrieves wallet address for on receipt order.
   */
  public async getOnReceiptWallet(params: {
    blockchain: string
    currency: string
    fund: string
    trade_type: string
  }): Promise<any> {
    const query = new URLSearchParams(params).toString()
    return this.request<any>(`/api/orders/on-receipt-wallet/?${query}`)
  }

  /**
   * Retrieves current user's organization details.
   */
  public async getMe(): Promise<any> {
    return this.request<any>('/api/organizations/me')
  }
}
