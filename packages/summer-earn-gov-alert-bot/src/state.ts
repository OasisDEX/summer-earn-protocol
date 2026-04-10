import * as fs from 'fs'
import path from 'path'

const STATE_FILE = path.join(__dirname, '../state.json')

export function loadState(): Record<string, bigint> {
  if (fs.existsSync(STATE_FILE)) {
    try {
      const data = JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'))
      return Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, BigInt(v as string)])
      )
    } catch (error) {
      console.error('Error loading state:', error)
      return {}
    }
  }
  return {}
}

export function saveState(state: Record<string, bigint>) {
  const data = Object.fromEntries(
    Object.entries(state).map(([k, v]) => [k, v.toString()])
  )
  fs.writeFileSync(STATE_FILE, JSON.stringify(data, null, 2))
}
