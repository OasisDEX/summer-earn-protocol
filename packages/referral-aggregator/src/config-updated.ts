import { Kysely } from 'kysely'
import { DB } from 'kysely-codegen'

export interface PointsConfig {
  processingIntervalHours: number
  activeUserThresholdUsd: number
  pointsFormulaBase: number
  pointsFormulaLogMultiplier: number
  enableBackfill: boolean
}

export class ConfigService {
  constructor(private db: Kysely<DB>) {}

  async getConfig(): Promise<PointsConfig> {
    const configRows = await this.db.selectFrom('points_config').selectAll().execute()

    const config: { [key: string]: string } = {}
    for (const row of configRows) {
      config[row.key] = row.value
    }

    return {
      processingIntervalHours: parseFloat(config.processing_interval_hours || '1'),
      activeUserThresholdUsd: parseFloat(config.active_user_threshold_usd || '1'),
      pointsFormulaBase: parseFloat(config.points_formula_base || '0.00005'),
      pointsFormulaLogMultiplier: parseFloat(config.points_formula_log_multiplier || '0.0005'),
      enableBackfill: config.enable_backfill === 'true',
    }
  }

  async updateConfig(key: string, value: string, description?: string): Promise<void> {
    await this.db
      .insertInto('points_config')
      .values({
        key,
        value,
        description: description || null,
      })
      .onConflict((oc) =>
        oc.column('key').doUpdateSet({
          value,
          description: description || null,
        }),
      )
      .execute()
  }
}
