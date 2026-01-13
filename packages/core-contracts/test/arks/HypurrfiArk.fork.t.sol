// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/HypurrfiArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract HypurrfiArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    HypurrfiArk public ark;
    HypurrfiArk public nextArk;

    address public constant hypurrfiPoolAddress =
        0xceCcE0EB9DD2Ef7996e01e25DD70e461F918A14b;
    address public hypurrfiAddressProvider =
        0xA73ff12D177D8F1Ec938c3ba0e87D33524dD5594;
    address public hypurrfiDataProvider =
        0x895C799a5bbdCb63B80bEE5BD94E7b9138D977d6;
    address public rewardsController =
        0x5280b0Bac1c8342F9dCeA2bC5B6121A1473A368C;

    IHypurrfiPool public hypurrfiPool;
    IERC20 public usdc;

    uint256 forkBlock = 21006480;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("hyperliquid"), forkBlock);

        usdc = IERC20(0xb88339CB7199b77E23DB6E890353E22632Ba630f);
        hypurrfiPool = IHypurrfiPool(hypurrfiPoolAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new HypurrfiArk(address(hypurrfiPool), rewardsController, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_Hypurrfi_fork() public {
        /** SETUP */
        uint256 amount = 1000 * 10 ** 6;
        deal(address(usdc), commander, amount);

        vm.prank(commander);
        usdc.forceApprove(address(ark), amount);

        /** EXPECTATIONS */
        vm.expectCall(
            address(hypurrfiPool),
            abi.encodeWithSelector(
                hypurrfiPool.supply.selector,
                address(usdc),
                amount,
                address(ark),
                0
            )
        );

        // Expect the Transfer event to be emitted - minted aTokens
        vm.expectEmit();
        emit IERC20.Transfer(
            0x0000000000000000000000000000000000000000,
            address(ark),
            amount
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        /** TEST */
        vm.startPrank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));

        /** CHECK ACCRUAL */
        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }
}
