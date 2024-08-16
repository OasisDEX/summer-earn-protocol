import fs from 'fs'
import hre from 'hardhat';
import path from "path";
import FleetModule, { FleetContracts } from '../ignition/modules/fleet';
import { getConfigByNetwork } from './config-handler';
import {BaseConfig} from "./config-types";
import { ModuleLogger } from './module-logger';
import { loadFleetDefinition } from './fleet-definition-handler';
import kleur from 'kleur';
import prompts from 'prompts';

async function deployFleet() {
    const network = hre.network.name;
    const config = getConfigByNetwork(network);

    // Get fleet definition path from user
    const configPath = path.resolve(__dirname, `fleets/something.json`)
    console.log("EXAMPLE", configPath);

    const response = await prompts({
        type: 'text',
        name: 'fleetDefinitionPath',
        message: 'Enter the definition file name (in /scripts/fleets):',
        validate: value => fs.existsSync(path.resolve(__dirname, `fleets/${value}`)) ? true : 'File does not exist'
    });

    const fleetDefinitionPath = path.resolve(__dirname, `fleets/${response.fleetDefinitionPath}`)
    console.log(kleur.green(`Loading fleet definition from: ${fleetDefinitionPath}`));

    const fleetDefinition = loadFleetDefinition(fleetDefinitionPath);

    console.log(kleur.blue('Fleet Definition:'));
    console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)));

    // Get core contracts from config
    const coreContracts: BaseConfig['core'] = config['core'];

    const assetSymbol = (fleetDefinition.assetSymbol.toLowerCase()) as keyof typeof config.tokens;
    if (!Object.keys(config.tokens).includes(assetSymbol)) {
        throw new Error(`No token address for symbol ${fleetDefinition.assetSymbol} found in config`)
    }
    const asset = config.tokens[assetSymbol]

    const deployedFleet = (await hre.ignition.deploy(FleetModule, {
        parameters: {
            FleetModule: {
                configurationManager: coreContracts.configurationManager,
                protocolAccessManager: coreContracts.protocolAccessManager,
                fleetName: fleetDefinition.fleetName,
                fleetSymbol: fleetDefinition.symbol,
                asset,
                initialArks: fleetDefinition.arks,
                initialMinimumFundsBufferBalance: fleetDefinition.initialMinimumFundsBufferBalance,
                initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
                depositCap: fleetDefinition.depositCap,
                initialTipRate: fleetDefinition.initialTipRate,
                minimumRateDifference: fleetDefinition.minimumRateDifference
            },
        },
    })) as FleetContracts;

    // Logging
    ModuleLogger.logFleet(deployedFleet);

    console.log(kleur.yellow().bold('\nIMPORTANT: Commander roles need to be granted via governance'));
    console.log(kleur.yellow('For each initial Ark and the buffer Ark, call:'));
    console.log(kleur.cyan(`ark.grantCommanderRole(${deployedFleet.fleetCommander.address})`));

    // console.log(kleur.yellow('\nInitial Arks:'));
    // for (const ark of Object.values(initialArks)) {
    //     console.log(kleur.cyan(ark))
    // }
    //
    // console.log(kleur.yellow('\nBuffer Ark:'));
    // console.log(kleur.cyan(bufferArk));
    //
    // // Log reminder for enlisting the fleet commander in the harbor command
    // console.log(kleur.yellow().bold('\nIMPORTANT: The Fleet Commander needs to be enlisted in the Harbor Command via governance'));
    // console.log(kleur.yellow('Call:'));
    // console.log(kleur.cyan(`harborCommand.enlistFleetCommander(${fleetCommander.address})`));
    //
    // console.log(kleur.green('Fleet deployment completed successfully!'));
    // console.log(kleur.yellow('Fleet Commander Address:'), kleur.cyan(deployedFleet.fleetCommander.address));
}

deployFleet().catch((error) => {
    console.error(kleur.red('Error during fleet deployment:'));
    console.error(error);
    process.exit(1);
});