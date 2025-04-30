// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {DescriptionHash} from "../test/utils/DescriptionHash.sol";

contract GetDescriptionHash is Script {
    function run() external {
        string
            memory description = "# SIP5.3: Multi-Chain AdmiralsQuarters Role Setup\n\n## Summary\nThis proposal grants the ADMIRALS_QUARTERS_ROLE to newly deployed AdmiralsQuarters contracts across all active chains in the Lazy Summer Protocol ecosystem and revokes the role from previous contracts.\n\n## Motivation\nThe AdmiralsQuarters contract requires the ADMIRALS_QUARTERS_ROLE in the ProtocolAccessManager to operate properly. This role is necessary for the contract to unstake and withdraw assets from fleets on behalf of users.\n\nNewly deployed AdmiralsQuarters contracts:\n- base: 0x6A6295C8047Abf5aE8f8224a168F661e4F3Ac838\n- arbitrum: 0x8cF2D41dd29aDE7E4f7555887E06A5dbE1f988EF\n- mainnet: 0x4758276018B944DFe320E98Da5C3f4c03c3a6BDB\n\nPrevious AdmiralsQuarters contracts to revoke role from:\n- base: 0x275CA55c32258CE10870CA4e44c071aa14A2C836\n- arbitrum: 0x275CA55c32258CE10870CA4e44c071aa14A2C836\n- mainnet: 0x275CA55c32258CE10870CA4e44c071aa14A2C836\n\n## Specifications\n\n### Actions\n1. On base: \n   - Grant ADMIRALS_QUARTERS_ROLE to AdmiralsQuarters at 0x6A6295C8047Abf5aE8f8224a168F661e4F3Ac838\n   - Revoke ADMIRALS_QUARTERS_ROLE from previous AdmiralsQuarters at 0x275CA55c32258CE10870CA4e44c071aa14A2C836\n2. Send cross-chain proposal to arbitrum to:\n   - Grant ADMIRALS_QUARTERS_ROLE to AdmiralsQuarters at 0x8cF2D41dd29aDE7E4f7555887E06A5dbE1f988EF\n   - Revoke ADMIRALS_QUARTERS_ROLE from previous AdmiralsQuarters at 0x275CA55c32258CE10870CA4e44c071aa14A2C836\n2. Send cross-chain proposal to mainnet to:\n   - Grant ADMIRALS_QUARTERS_ROLE to AdmiralsQuarters at 0x4758276018B944DFe320E98Da5C3f4c03c3a6BDB\n   - Revoke ADMIRALS_QUARTERS_ROLE from previous AdmiralsQuarters at 0x275CA55c32258CE10870CA4e44c071aa14A2C836\n\n## Technical Details\nThe ADMIRALS_QUARTERS_ROLE is defined in the ProtocolAccessManager contract and is specifically designed for the AdmiralsQuarters contract. This role enables the contract to perform unstaking and withdrawal operations from fleets on behalf of users.\n\nWhen a user interacts with the AdmiralsQuarters interface to withdraw assets from fleets, the contract uses this role to execute the necessary transactions, ensuring a streamlined user experience while maintaining proper access controls.";
        DescriptionHash descHasher = new DescriptionHash();
        descHasher.logDescriptionHash(description);
    }
}
