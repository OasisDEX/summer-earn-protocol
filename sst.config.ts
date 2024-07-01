import { SSTConfig } from 'sst'
import { API } from './stacks/summer-stack'
import { ExternalAPI } from './stacks/partners-stack'
import { SdkAPI } from './stacks/sdk-stack'
import { $, chalk, echo } from 'zx'

const availableStage = ['dev', 'feature', 'staging', 'production']

enum App {
  SummerfiStack = 'summerfi-stack',
  Sdk = 'sdk',
}
const availableApps: string[] = [App.SummerfiStack, App.Sdk]

const getCurrentBranch = async () => {
  const { stdout: currentBranch } = await $`git branch --show-current`
  return currentBranch.trim()
}

const checkRemoteBranchExists = async (branchName: string) => {
  try {
    await $`git ls-remote --exit-code --heads origin ${branchName}`
    return true
  } catch (error) {
    return false
  }
}

const checkForUncommittedOrUntrackedChanges = async () => {
  const { stdout: status } = await $`git status --porcelain`
  return status.trim().split('\n').filter(Boolean).length
}

const runInstallAndChecks = async () => {
  try {
    await $`pnpm install`
    await $`pnpm run cicheck`
  } catch (error) {
    echo(`cicheck failed: ${error.message}`)
    return false
  }

  return true
}

const getCommitsToFetch = async (currentBranch: string): Promise<number | null> => {
  if (!(await checkRemoteBranchExists(currentBranch))) {
    echo('Remote branch does not exist')
    return null
  }
  await $`git fetch origin ${currentBranch}`

  const { stdout: commitsToFetch } =
    await $`git rev-list ${currentBranch}..origin/${currentBranch} --count`
  return Number(commitsToFetch.trim())
}

const checkIfDockerIsRunning = async () => {
  try {
    await $`docker version > /dev/null 2>&1`
  } catch (error) {
    return false
  }
  return true
}

const checkIfDockerComposeIsRunning = async () => {
  try {
    const { stdout } =
      await $`docker compose --file ./stacks/local-env/docker-compose.yaml  ps --services --filter "status=running"`
    const services = (stdout ?? '').trim().split('\n').filter(Boolean)
    return services.length > 0
  } catch (error) {
    return false
  }
}

const runDockerCompose = async () => {
  try {
    await $`docker compose --file ./stacks/local-env/docker-compose.yaml up -d`
  } catch (error) {
    echo(`${chalk.bgRed('Failed to start docker-compose services' + error.message)}`)
    return false
  }

  return true
}

export const sstConfig: SSTConfig = {
  async config(_input) {
    // read app from cli input
    const { app } = _input as { app?: string }

    const currentBranch = await getCurrentBranch()
    const commitsToFetch = await getCommitsToFetch(currentBranch)
    if (commitsToFetch === null) {
      echo(
        `You are on the ${currentBranch} branch and there is no remote branch to fetch commits from`,
      )
    } else {
      echo(
        `You are on the ${currentBranch} branch and there are ${commitsToFetch} commits to fetch from origin`,
      )
    }

    if (_input.stage === 'staging' || _input.stage === 'production') {
      if (_input.stage === 'production') {
        if (currentBranch !== 'main' && currentBranch !== 'dev') {
          throw new Error('You can only deploy to production from main or dev branch')
        }
      }

      if (commitsToFetch === null) {
        throw new Error('Cannot find remote branch to fetch commits from')
      }
      if (commitsToFetch > 0) {
        throw new Error(
          `You have ${commitsToFetch} commits to fetch from origin. Please fetch them before deploying to staging or production`,
        )
      }

      const result = await runInstallAndChecks()
      if (!result) {
        throw new Error('Cannot deploy with failing checks')
      }

      const changes = await checkForUncommittedOrUntrackedChanges()

      if (changes > 0) {
        throw new Error(
          `Cannot deploy with uncommitted or untracked changes. Current status: ${changes} changes`,
        )
      }
    }

    if (_input.stage === undefined && process.env.SST_USER === undefined) {
      throw new Error('Please specify stage or set SST_USER env variable')
    }

    if (_input.stage && !availableStage.includes(_input.stage)) {
      throw new Error('Invalid stage, use one of: ' + availableStage.join(', '))
    }

    const stage = _input.stage ?? `dev-${process.env.SST_USER}`

    if (stage.startsWith('dev-')) {
      const isDockerRunning = await checkIfDockerIsRunning()
      if (!isDockerRunning) {
        echo`${chalk.bgYellow('Docker is not running. ')}`
        echo`${chalk.bgYellow('Docker is required for some resources to work properly.')}`
      } else {
        echo`${chalk.green('Docker is running. ')}`
        const isDockerComposeRunning = await checkIfDockerComposeIsRunning()
        if (!isDockerComposeRunning) {
          echo`${chalk.bgBlue('Local docker-compose is not running. Trying to start the services... ')}`
          await runDockerCompose()
        } else {
          echo`${chalk.green('Docker Compose is running. ')}`
        }
      }
    }

    if (!app || availableApps.includes(app) === false) {
      throw new Error('Invalid --app argument, use one of: ' + availableApps.join(', '))
    }

    return {
      name: app,
      region: `${process.env.AWS_REGION}`,
      profile: `${process.env.AWS_PROFILE}`,
      stage: stage,
    }
  },
  stacks(app) {
    if (app.stage !== 'production' && app.stage !== 'staging') {
      app.setDefaultRemovalPolicy('destroy')
    } else {
      app.setDefaultRemovalPolicy('retain')
    }
    echo`\n`
    if (app.name === App.SummerfiStack) {
      app.stack(API)
      app.stack(ExternalAPI)
    }
    if (app.name === App.Sdk) {
      app.stack(SdkAPI)
    }
  },
}

export default sstConfig
