import hre from "hardhat";
import ProtocolCore from "../ignition/modules/protocol-core";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from 'fs';
import path from 'path';

// Load the addresses from the JSON file
const addresses = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'addresses.json'), 'utf8'));

async function main() {
    const { protocolAccessManager, tipJar, raft, configurationManager } = await hre.ignition.deploy(ProtocolCore, {
        parameters: { ProtocolCore: { swapProvider: '0x0', multiSigTreasury: '0x0' } },
    });

    // Logging

    // Store addresses
    // console.log(`Pro deployed to: ${await apollo.getAddress()}`);
}

main().catch(console.error);