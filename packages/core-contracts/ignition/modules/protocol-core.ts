import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Protocol Core", (m) => {
    // Addresses
    const deployer = m.getAccount(0);
    const multiSigTreasury = process.env.MULTISIG_TREASURY_ADDRESS || "";
    const swapProvider = process.env.SWAP_PROVIDER || "";

    if (multiSigTreasury == '') throw new Error("Multi-sig Treasury not defined");
    if (swapProvider == '') throw new Error("Swap provider not defined");

    const protocolAccessManager = m.contract("ProtocolAccessManager", [deployer]);
    const tipJar = m.contract("TipJar", [protocolAccessManager, multiSigTreasury]);
    const raft = m.contract("Raft", [swapProvider, protocolAccessManager]);
    const configurationManager = m.contract("ConfigurationManager", [protocolAccessManager, raft, tipJar]);
    const harborCommander = m.contract("HarborCommand", [protocolAccessManager]);

    return { protocolAccessManager, tipJar, raft, configurationManager };
});