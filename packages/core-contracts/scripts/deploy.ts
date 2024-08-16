import {deployCore} from "./deploy-core";

async function main() {
    await deployCore();
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
