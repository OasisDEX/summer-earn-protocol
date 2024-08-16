import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

export default buildModule('FleetModule', (m) => {
    const configurationManager = m.getParameter<string>('configurationManager');
    const protocolAccessManager = m.getParameter<string>('protocolAccessManager');
    const fleetName = m.getParameter<string>('fleetName');
    const fleetSymbol = m.getParameter<string>('fleetSymbol');
    const asset = m.getParameter<string>('asset');
    const initialArks = m.getParameter<string[]>('initialArks');
    const initialMinimumFundsBufferBalance = m.getParameter<string>('initialMinimumFundsBufferBalance');
    const initialRebalanceCooldown = m.getParameter<string>('initialRebalanceCooldown');
    const depositCap = m.getParameter<string>('depositCap');
    const initialTipRate = m.getParameter<string>('initialTipRate');
    const minimumRateDifference = m.getParameter<string>('minimumRateDifference');
    const bufferArkParams = m.getParameter<any>('bufferArkParams');

    // Deploy BufferArk directly
    const bufferArk = m.contract('BufferArk', [bufferArkParams]);

    const fleetCommander = m.contract('FleetCommander', [
        {
            name: fleetName,
            symbol: fleetSymbol,
            initialArks: initialArks,
            configurationManager: configurationManager,
            accessManager: protocolAccessManager,
            asset: asset,
            bufferArk: bufferArk,
            initialMinimumFundsBufferBalance: initialMinimumFundsBufferBalance,
            initialRebalanceCooldown: initialRebalanceCooldown,
            depositCap: depositCap,
            initialTipRate: initialTipRate,
            minimumRateDifference: minimumRateDifference
        }
    ]);

    return { fleetCommander, bufferArk };
});

export type FleetContracts = {
    fleetCommander: { address: string };
    bufferArk: { address: string };
};