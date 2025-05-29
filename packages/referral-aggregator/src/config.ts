import { Kysely } from 'kysely'
import { Database } from './database/types'

export interface PointsConfig {
  processingIntervalHours: number
  activeUserThresholdUsd: number
  pointsFormulaBase: number
  pointsFormulaLogMultiplier: number
  enableBackfill: boolean
}

export class ConfigService {
  constructor(private db: Kysely<Database>) {}

  async getConfig(): Promise<PointsConfig> {
    const result = await this.db
      .selectFrom('points_config')
      .select(['key', 'value'])
      .where('key', 'in', [
        'processing_interval_hours',
        'active_user_threshold_usd',
        'points_formula_base',
        'points_formula_log_multiplier',
        'enable_backfill',
      ])
      .execute()

    const config: any = {}

    for (const row of result) {
      config[row.key] = row.value
    }

    return {
      processingIntervalHours: parseFloat(config.processing_interval_hours || '1'),
      activeUserThresholdUsd: parseFloat(config.active_user_threshold_usd || '100'),
      pointsFormulaBase: parseFloat(config.points_formula_base || '0.00005'),
      pointsFormulaLogMultiplier: parseFloat(config.points_formula_log_multiplier || '0.0005'),
      enableBackfill: config.enable_backfill === 'true',
    }
  }

  async updateConfig(key: string, value: string): Promise<void> {
    await this.db
      .updateTable('points_config')
      .set({
        value,
        updated_at: new Date(),
      })
      .where('key', '=', key)
      .execute()
  }

  async getProcessingIntervalMs(): Promise<number> {
    const config = await this.getConfig()
    return config.processingIntervalHours * 60 * 60 * 1000
  }
}
