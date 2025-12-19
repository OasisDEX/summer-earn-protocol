// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/HyperlendArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract HyperlendArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    HyperlendArk public ark;
    HyperlendArk public nextArk;

    address public constant hyperlendPoolAddress =
        0x00A89d7a5A02160f20150EbEA7a2b5E4879A1A8b;
    address public hyperlendAddressProvider =
        0x72c98246a98bFe64022a3190e7710E157497170C;
    address public hyperlendDataProvider =
        0x5481bf8d3946E6A3168640c1D7523eB59F055a29;
    address public rewardsController =
        0x2aF0d6754A58723c50b5e73E45D964bFDD99fE2F;
    IHyperlendPool public hyperlendPool;

    address public mockAToken = address(11);

    function setUp() public {
        initializeCoreContracts();
        mockToken = new ERC20Mock();
        hyperlendPool = IHyperlendPool(hyperlendPoolAddress);

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
        HyperlendDataTypes.ReserveData memory reserveData = HyperlendDataTypes
            .ReserveData({
                configuration: HyperlendDataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined
                // and 0 is a placeholder
                liquidityIndex: 1e27, // Example value in ray
                currentLiquidityRate: 1e27, // Example value in ray
                variableBorrowIndex: 1e27, // Example value in ray
                currentVariableBorrowRate: 1e27, // Example value in ray
                __deprecatedStableBorrowRate: 0, // Deprecated field
                lastUpdateTimestamp: uint40(block.timestamp), // Current timestamp as example
                id: 1, // Example value
                liquidationGracePeriodUntil: 0, // Liquidations are enabled
                aTokenAddress: mockAToken,
                __deprecatedStableDebtTokenAddress: address(0), // Deprecated field
                variableDebtTokenAddress: address(0), // Placeholder address
                interestRateStrategyAddress: address(0), // Placeholder address
                accruedToTreasury: 0, // Example value
                unbacked: 0, // Example value
                isolationModeTotalDebt: 0, // Example value
                virtualUnderlyingBalance: 0 // Example value
            });
        vm.mockCall(
            address(hyperlendPool),
            abi.encodeWithSelector(
                IHyperlendPool(hyperlendPool).getReserveDataExtended.selector
            ),
            abi.encode(reserveData)
        );
        ark = new HyperlendArk(
            address(hyperlendPool),
            rewardsController,
            params
        );
        nextArk = new HyperlendArk(
            address(hyperlendPool),
            rewardsController,
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
        HyperlendDataTypes.ReserveData memory reserveData = HyperlendDataTypes
            .ReserveData({
                configuration: HyperlendDataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined
                // and 0 is a placeholder
                liquidityIndex: 1e27, // Example value in ray
                currentLiquidityRate: 1e27, // Example value in ray
                variableBorrowIndex: 1e27, // Example value in ray
                currentVariableBorrowRate: 1e27, // Example value in ray
                __deprecatedStableBorrowRate: 0, // Deprecated field
                lastUpdateTimestamp: uint40(block.timestamp), // Current timestamp as example
                id: 1, // Example value
                liquidationGracePeriodUntil: 0, // Liquidations are enabled
                aTokenAddress: mockAToken,
                __deprecatedStableDebtTokenAddress: address(0), // Deprecated field
                variableDebtTokenAddress: address(0), // Placeholder address
                interestRateStrategyAddress: address(0), // Placeholder address
                accruedToTreasury: 0, // Example value
                unbacked: 0, // Example value
                isolationModeTotalDebt: 0, // Example value
                virtualUnderlyingBalance: 0 // Example value
            });
        vm.mockCall(
            address(hyperlendPool),
            abi.encodeWithSelector(
                IHyperlendPool(hyperlendPool).getReserveDataExtended.selector
            ),
            abi.encode(reserveData)
        );
        ark = new HyperlendArk(
            address(hyperlendPool),
            rewardsController,
            params
        );
        assertEq(address(ark.hyperlendPool()), address(hyperlendPool));

        assertEq(address(ark.asset()), address(mockToken));
        assertEq(ark.depositCap(), type(uint256).max);
        assertEq(ark.aToken(), mockAToken);
        assertEq(ark.name(), "TestArk");
    }

    function test_Board() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);

        vm.mockCall(
            address(hyperlendPool),
            abi.encodeWithSelector(
                hyperlendPool.supply.selector,
                address(mockToken),
                amount,
                address(this),
                0
            ),
            abi.encode()
        );

        vm.expectCall(
            address(hyperlendPool),
            abi.encodeWithSelector(
                hyperlendPool.supply.selector,
                address(mockToken),
                amount,
                address(ark),
                0
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));
    }

    function test_Disembark() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            address(hyperlendPool),
            abi.encodeWithSelector(
                hyperlendPool.withdraw.selector,
                address(mockToken),
                amount,
                address(ark)
            ),
            abi.encode(amount)
        );

        vm.expectCall(
            address(hyperlendPool),
            abi.encodeWithSelector(
                hyperlendPool.withdraw.selector,
                address(mockToken),
                amount,
                address(ark)
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.disembark(amount, bytes(""));
    }

    function test_Harvest() public {
        // Setup mock reward token and amount
        address[] memory rewardTokens = new address[](1);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(10);
        rewardAmounts[0] = 1000 * 10 ** 18;

        // Mock the claimAllRewards call
        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = mockAToken;

        vm.mockCall(
            address(rewardsController),
            abi.encodeWithSelector(
                IRewardsController.claimAllRewards.selector,
                incentivizedAssets,
                address(raft)
            ),
            abi.encode(rewardTokens, rewardAmounts)
        );

        // Expect the ArkHarvested event with correct parameters
        vm.expectEmit();
        emit ArkHarvested(rewardTokens, rewardAmounts);

        // Execute harvest as raft
        vm.prank(address(raft));
        ark.harvest("");
    }
}
