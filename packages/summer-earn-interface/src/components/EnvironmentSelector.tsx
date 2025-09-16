import { Environment } from '../config/environments'

interface EnvironmentSelectorProps {
  selectedEnvironment: Environment
  onChange: (environment: Environment) => void
}

export function EnvironmentSelector({ selectedEnvironment, onChange }: EnvironmentSelectorProps) {
  return (
    <div className="mb-4">
      <label className="block text-sm font-medium text-white mb-2">Environment</label>
      <div className="flex space-x-4">
        <label className="inline-flex items-center">
          <input
            type="radio"
            className="form-radio text-blue-500 border-gray-600 bg-gray-800 focus:ring-blue-500"
            name="environment"
            value="production"
            checked={selectedEnvironment === 'production'}
            onChange={(e) => onChange(e.target.value as Environment)}
          />
          <span className="ml-2 text-gray-300">Production</span>
        </label>
        <label className="inline-flex items-center">
          <input
            type="radio"
            className="form-radio text-blue-500 border-gray-600 bg-gray-800 focus:ring-blue-500"
            name="environment"
            value="staging"
            checked={selectedEnvironment === 'staging'}
            onChange={(e) => onChange(e.target.value as Environment)}
          />
          <span className="ml-2 text-gray-300">Staging</span>
        </label>
      </div>
    </div>
  )
}
