// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {DescriptionHash} from "../test/utils/DescriptionHash.sol";

contract GetDescriptionHash is Script {
    function run() external {
        string
            memory description = "# SIP1.1: Cross-chain Fleet Deployment Proposal\n\n## Summary\nThis is a cross-chain governance proposal to activate the LazyVault_LowerRisk_USDC Fleet on arbitrum.\n\n## Motivation\nThis cross-chain fleet deployment will expand the protocol's capabilities across multiple networks.\n\n## Technical Details\n- Hub Chain: base (Production)\n- Target Chain: arbitrum\n- Fleet Commander: 0x4F63cfEa7458221CB3a0EEE2F31F7424Ad34bb58\n- Buffer Ark: 0xbb79242B9518F450cDe8eb957E15c38ab09B1419\n- Number of Arks: 4\n- Curator: 0xa16f07B4Dd32250DEc69C63eCd0aef6CD6096d3d\n\n### Token Bridge\n- Amount: 10,000,000 tokens (10000000000000000000000000 raw)\n- Destination: Arbitrum - Treasury (SummerTimelock) 0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796\n\n\n## Specifications\n### Actions\nThis proposal will execute the following actions on arbitrum:\n1. Bridge 10,000,000 (10000000000000000000000000 raw) tokens to the target chain\n2. Add Fleet to Harbor Command\n3. Grant COMMANDER_ROLE to Fleet Commander for BufferArk\n4. Add 4 Arks to the Fleet\n5. Grant COMMANDER_ROLE to Fleet Commander for each Ark\n6. Grant CURATOR_ROLE to Curator for the Fleet\n7. Set up rewards for 1 tokens\n\n### Cross-chain Mechanism\nThis proposal uses LayerZero to execute governance actions across chains.\n\n### Fleet Configuration\n- Deposit Cap: 0 (0 raw)\n- Initial Minimum Buffer Balance: 100 (100000000 raw)\n- Initial Rebalance Cooldown: 10 minutes (600 seconds)\n- Initial Tip Rate: 1% (10000000000000000 raw)\n\n### Rewards Configuration\n- Reward Tokens: 0x194f360D130F2393a5E9F3117A6a1B78aBEa1624\n- Reward Amounts: 1,537,243 tokens (1537243000000000000000000)\n- Rewards Duration: 57 days (4924800 seconds)\n";
        DescriptionHash descHasher = new DescriptionHash();
        descHasher.logDescriptionHash(description);
    }
}
