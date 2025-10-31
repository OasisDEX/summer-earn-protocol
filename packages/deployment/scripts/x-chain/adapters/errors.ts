export class AdapterConfigurationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'AdapterConfigurationError'
  }
}

export class AdapterValidationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'AdapterValidationError'
  }
}
