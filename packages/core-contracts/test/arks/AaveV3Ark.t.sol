// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/AaveV3Ark.sol";
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

contract AaveV3ArkTest is Test, IArkEvents, ArkTestBase {
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

    address public mockAToken = address(11);

    function setUp() public {
        initializeCoreContracts();
        mockToken = new ERC20Mock();
        aaveV3Pool = IPoolV3(aaveV3PoolAddress);

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
            configuration: DataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined
            // and 0 is a placeholder
            liquidityIndex: 1e27, // Example value in ray
            currentLiquidityRate: 1e27, // Example value in ray
            variableBorrowIndex: 1e27, // Example value in ray
            currentVariableBorrowRate: 1e27, // Example value in ray
            currentStableBorrowRate: 1e27, // Example value in ray
            lastUpdateTimestamp: uint40(block.timestamp), // Current timestamp as example
            id: 1, // Example value
            aTokenAddress: mockAToken,
            stableDebtTokenAddress: address(0), // Placeholder address
            variableDebtTokenAddress: address(0), // Placeholder address
            interestRateStrategyAddress: address(0), // Placeholder address
            accruedToTreasury: 0, // Example value
            unbacked: 0, // Example value
            isolationModeTotalDebt: 0 // Example value
        });
        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).getReserveData.selector),
            abi.encode(reserveData)
        );
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
            configuration: DataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined
            // and 0 is a placeholder
            liquidityIndex: 1e27, // Example value in ray
            currentLiquidityRate: 1e27, // Example value in ray
            variableBorrowIndex: 1e27, // Example value in ray
            currentVariableBorrowRate: 1e27, // Example value in ray
            currentStableBorrowRate: 1e27, // Example value in ray
            lastUpdateTimestamp: uint40(block.timestamp), // Current timestamp as example
            id: 1, // Example value
            aTokenAddress: address(0), // Placeholder address
            stableDebtTokenAddress: address(0), // Placeholder address
            variableDebtTokenAddress: address(0), // Placeholder address
            interestRateStrategyAddress: address(0), // Placeholder address
            accruedToTreasury: 0, // Example value
            unbacked: 0, // Example value
            isolationModeTotalDebt: 0 // Example value
        });
        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).getReserveData.selector),
            abi.encode(reserveData)
        );
        ark = new AaveV3Ark(address(aaveV3Pool), rewardsController, params);
        assertEq(address(ark.aaveV3Pool()), address(aaveV3Pool));

        assertEq(address(ark.asset()), address(mockToken));
        assertEq(ark.depositCap(), type(uint256).max);
        assertEq(ark.aToken(), address(0));
        assertEq(ark.name(), "TestArk");
    }

    function test_Board() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);

        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.supply.selector,
                address(mockToken),
                amount,
                address(this),
                0
            ),
            abi.encode()
        );

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.supply.selector,
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
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.withdraw.selector,
                address(mockToken),
                amount,
                address(ark)
            ),
            abi.encode(amount)
        );

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.withdraw.selector,
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
