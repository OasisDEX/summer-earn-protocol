import { ProtocolCoreContracts } from '../ignition/modules/protocol-core';

export class ModuleLogger {
    private moduleName: string;
    private contracts: Record<string, { address: string }>;

    constructor(moduleName: string, contracts: Record<string, { address: string }>) {
        this.moduleName = moduleName;
        this.contracts = contracts;
    }

    logAddresses(): void {
        console.log(`\n${this.moduleName} Deployment Addresses:`);
        console.log('======================================');

        for (const [contractName, contract] of Object.entries(this.contracts)) {
            console.log(`${contractName}: ${contract.address}`);
        }

        console.log('======================================\n');
    }

    static logProtocolCore(contracts: ProtocolCoreContracts): void {
        const logger = new ModuleLogger('Protocol Core', {
            'Protocol Access Manager': contracts.protocolAccessManager,
            'Tip Jar': contracts.tipJar,
            'Raft': contracts.raft,
            'Configuration Manager': contracts.configurationManager,
        });
        logger.logAddresses();
    }
}