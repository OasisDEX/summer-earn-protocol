import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ProtocolCore", (m) => {
    // Addresses
    const deployer = m.getAccount(0);
    const swapProvider = m.getParameter("swapProvider");
    const multiSigTreasury = m.getParameter("multiSigTreasury");

    const protocolAccessManager = m.contract("ProtocolAccessManager", [deployer]);
    const tipJar = m.contract("TipJar", [protocolAccessManager, multiSigTreasury]);
    const raft = m.contract("Raft", [swapProvider, protocolAccessManager]);
    const configurationManager = m.contract("ConfigurationManager", [protocolAccessManager, raft, tipJar]);
    const harborCommander = m.contract("HarborCommand", [protocolAccessManager]);

    return { protocolAccessManager, tipJar, raft, configurationManager };
});