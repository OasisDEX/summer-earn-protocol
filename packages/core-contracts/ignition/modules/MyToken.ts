import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("FleetCommander", (m) => {
    const token = m.contract("FleetCommander", ["My Token", "TKN", 18]);

    return { token };
});