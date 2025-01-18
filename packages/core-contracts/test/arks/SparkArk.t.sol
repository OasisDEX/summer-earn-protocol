// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SparkArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract SparkArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    SparkArk public ark;
    SparkArk public nextArk;

    address public constant sparkPoolAddress =
        0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address public sparkRewardsController =
        0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    IPoolV3 public sparkPool;

    address public mockSpToken = address(11);

    function setUp() public {
        initializeCoreContracts();
        mockToken = new ERC20Mock();
        sparkPool = IPoolV3(sparkPoolAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        DataTypes.ReserveData memory reserveData = DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0),
            liquidityIndex: 1e27,
            currentLiquidityRate: 1e27,
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: 1e27,
            currentStableBorrowRate: 1e27,
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 1,
            aTokenAddress: mockSpToken,
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
        vm.mockCall(
            address(sparkPool),
            abi.encodeWithSelector(IPoolV3(sparkPool).getReserveData.selector),
            abi.encode(reserveData)
        );
        ark = new SparkArk(address(sparkPool), sparkRewardsController, params);
        nextArk = new SparkArk(
            address(sparkPool),
            sparkRewardsController,
            params
        );

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

    function test_Constructor() public {
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        DataTypes.ReserveData memory reserveData = DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0),
            liquidityIndex: 1e27,
            currentLiquidityRate: 1e27,
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: 1e27,
            currentStableBorrowRate: 1e27,
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 1,
            aTokenAddress: address(0),
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
        vm.mockCall(
            address(sparkPool),
            abi.encodeWithSelector(IPoolV3(sparkPool).getReserveData.selector),
            abi.encode(reserveData)
        );
        ark = new SparkArk(address(sparkPool), sparkRewardsController, params);
        assertEq(address(ark.sparkPool()), address(sparkPool));
        assertEq(address(ark.asset()), address(mockToken));
        assertEq(ark.depositCap(), type(uint256).max);
        assertEq(ark.spToken(), address(0));
        assertEq(ark.name(), "TestArk");
    }

    function test_Board() public {
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);

        vm.mockCall(
            address(sparkPool),
            abi.encodeWithSelector(
                sparkPool.supply.selector,
                address(mockToken),
                amount,
                address(this),
                0
            ),
            abi.encode()
        );

        vm.expectCall(
            address(sparkPool),
            abi.encodeWithSelector(
                sparkPool.supply.selector,
                address(mockToken),
                amount,
                address(ark),
                0
            )
        );

        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);

        vm.prank(commander);
        ark.board(amount, bytes(""));
    }

    function test_Disembark() public {
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            address(sparkPool),
            abi.encodeWithSelector(
                sparkPool.withdraw.selector,
                address(mockToken),
                amount,
                address(ark)
            ),
            abi.encode(amount)
        );

        vm.expectCall(
            address(sparkPool),
            abi.encodeWithSelector(
                sparkPool.withdraw.selector,
                address(mockToken),
                amount,
                address(ark)
            )
        );

        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);

        vm.prank(commander);
        ark.disembark(amount, bytes(""));
    }

    function test_Harvest() public {
        address[] memory rewardTokens = new address[](1);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(10);
        rewardAmounts[0] = 1000 * 10 ** 18;

        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = mockSpToken;

        vm.mockCall(
            address(sparkRewardsController),
            abi.encodeWithSelector(
                IRewardsController.claimAllRewards.selector,
                incentivizedAssets,
                address(raft)
            ),
            abi.encode(rewardTokens, rewardAmounts)
        );

        vm.expectEmit();
        emit ArkHarvested(rewardTokens, rewardAmounts);

        vm.prank(address(raft));
        ark.harvest("");
    }
}
