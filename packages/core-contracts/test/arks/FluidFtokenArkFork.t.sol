// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FluidFTokenArk} from "../../src/contracts/arks/FluidFTokenArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {console} from "forge-std/console.sol";

contract FluidFTokenArkForkTest is ArkTestBase, IArkEvents {
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // existing ark address - one that accrues rewards
    address constant ARK_ADDRESS = 0xDB6d68d571FbEF7D67827844DD800884EA9cc02E;
    address constant CLAIMER = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0;
    uint256 constant FORK_BLOCK = 23570930;

    function setUp() public {
        initializeCoreContracts();
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        // Deploy a temp instance to obtain runtime code for etching (must pass constructor checks)
        ArkParams memory params = ArkParams({
            name: "Temp",
            details: "Temp",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS, // USDC mainnet
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        // Deploy a minimal ERC4626 vault mock with correct asset so constructor succeeds
        ERC4626Mock vault = new ERC4626Mock(USDC_ADDRESS);
        FluidFTokenArk temp = new FluidFTokenArk(address(vault), params);
        bytes memory runtimeCode = address(temp).code;

        vm.etch(ARK_ADDRESS, runtimeCode);
    }

    function test_Harvest_Fork_ClaimOrNoop() public {
        // Build claim data from actual data
        // data comes from currently deployed ark without the harvest method implemented
        address posAddr = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        bytes32 positionId = bytes32(uint256(uint160(posAddr)));
        bytes32[] memory proof = new bytes32[](14);
        proof[
            0
        ] = 0x9504b9caa356b4483d0fd2deb8a8ce142809317e8603cd614533c2fbb6a96faa;
        proof[
            1
        ] = 0x449f1d4de4d3e39f8edf6ea436c73c87ef64606d7600f9735ec726af7dc55934;
        proof[
            2
        ] = 0xaa659a4dac8a96b8f7d5338cb2e4716422a6d63fc8177c54b4db6d8e9e49ac92;
        proof[
            3
        ] = 0x5ca2707909b1ae4dd63618845e1d6cc1f30a965190f4f1a27176988dd6f1f872;
        proof[
            4
        ] = 0xa34fc45dc0f7626fbdf5e952e549857aa2ec14836095a20b17055e5c0d157b75;
        proof[
            5
        ] = 0x5c8c06524743daaa2b989eb36760e9b3a6c7c6c41413cde7281d7a2d30c30441;
        proof[
            6
        ] = 0xf6868a19210c2b768b83e8097795acbe8fce46529737008172fd01e3c22b7d99;
        proof[
            7
        ] = 0xc6d9a1ccdc7a9f35df31d47b1b61b88cfb1d7e1e1da8cf233e0d085b832de861;
        proof[
            8
        ] = 0x810b368d86d101bb11e12d92413621dd4ceeb661c57a070262f7dce50c9ddf20;
        proof[
            9
        ] = 0xc2997e8f0278ed66034311f862c218b42d5deffb0b7201147dfc2daf25d84d41;
        proof[
            10
        ] = 0xb60662e03c0bd317a4367971cfb7feada3a06eddc4f9e94b1fb7c1fce7a6c7d1;
        proof[
            11
        ] = 0x654bb1515eca4371016f7998b6ed5014363a29429f183b1c230e0f49131c38d6;
        proof[
            12
        ] = 0x0572ed25e9225a472e282e6f98d4fb92620d4d68a0ca8d1a37b9cd5b16875550;
        proof[
            13
        ] = 0xc2c214bad8300eae4196abdf1e0290c9933480b69fec5a6e134454236c1ee2dd;

        FluidFTokenArk.ClaimData memory claimData = FluidFTokenArk.ClaimData({
            merkleClaimer: CLAIMER,
            recipient: ARK_ADDRESS,
            cumulativeAmount: 1374128977332271889119,
            positionType: 1,
            positionId: positionId,
            cycle: 912,
            merkleProof: proof,
            metadata: bytes("")
        });

        // Determine raft from live configuration via etched code
        address raftAddr = FluidFTokenArk(ARK_ADDRESS).raft();

        vm.prank(raftAddr);
        (address[] memory tokens, uint256[] memory amounts) = FluidFTokenArk(
            ARK_ADDRESS
        ).harvest(abi.encode(claimData));

        // Non-reverting and returns a token address
        assertEq(tokens.length, 1);
        assertTrue(tokens[0] != address(0));
        assertEq(amounts.length, 1);
        console.log("tokens[0]", tokens[0]);
        console.log("amounts[0]", amounts[0]);
        // If already claimed, amount can be 0; assert no reverts and arrays are well-formed
        // We cannot know the token here to assert raft balance delta across chains reliably
        (tokens, amounts); // silence warnings
    }
}
