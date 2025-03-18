// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {DescriptionHash} from "../test/utils/DescriptionHash.sol";

contract GetDescriptionHash is Script {
    function run() external {
        string
            memory description = "# SIP3.2: Cross-chain Reward Setup Proposal for LazyVault_LowerRisk_USDCe Fleet on Sonic\n\n## Summary\nThis is a cross-chain governance proposal to set up rewards for the LazyVault_LowerRisk_USDCe Fleet on sonic.\n\n## Motivation\nSetting up rewards incentivizes liquidity providers and participants in the LazyVault_LowerRisk_USDCe Fleet ecosystem on sonic.\n\n## Technical Details\n- Hub Chain: base (Production)\n- Target Chain: sonic\n- Fleet Commander: 0x507A2D9E87DBD3076e65992049C41270b47964f8\n- Number of Reward Tokens: 1\n\n### Rewards Configuration\n- Reward Tokens: 0x4e0037f487bBb588bf1B7a83BDe6c34FeD6099e3\n- Reward Amounts: 1,240,582 tokens (1240582000000000000000000)\n- Rewards Durations: 46 days (3974400 seconds)\n\n## Specifications\n### Actions\nThis proposal will execute the following actions on sonic:\n1. Whitelist rewards manager as a rewarder\n2. Approve token transfers for rewards\n3. Notify reward amounts for 1 tokens with appropriate durations\n\n### Cross-chain Mechanism\nThis proposal uses LayerZero to execute governance actions across chains.\n\n## References\nDiscourse: https://forum.summer.fi/t/the-path-to-1b-tvl-onboard-medium-and-high-risk-vaults-for-lazy-summer-protocol/113";
        DescriptionHash descHasher = new DescriptionHash();
        descHasher.logDescriptionHash(description);
    }
}
