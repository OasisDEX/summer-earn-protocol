// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/AaveV3Ark.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveV3ArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    AaveV3Ark public ark;
    AaveV3Ark public nextArk;

    address public constant aaveV3PoolAddress =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public aaveAddressProvider =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public aaveV3DataProvider =
        0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
    address public rewardsController =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;

    IPoolV3 public aaveV3Pool;
    IERC20 public usdt;

    uint256 forkBlock = 20006596;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        aaveV3Pool = IPoolV3(aaveV3PoolAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdt),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new AaveV3Ark(address(aaveV3Pool), rewardsController, params);
        nextArk = new AaveV3Ark(address(aaveV3Pool), rewardsController, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCommanderRole(
            address(address(nextArk)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        nextArk.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_AaveV3_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        deal(address(usdt), commander, amount);

        vm.prank(commander);
        usdt.forceApprove(address(ark), amount);

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.supply.selector,
                address(usdt),
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
        emit Boarded(commander, address(usdt), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }
}
