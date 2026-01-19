// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/HypurrfiArk.sol";
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

contract HypurrfiArkTest is Test, IArkEvents, ArkTestBase {
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

    address public mockAToken = address(11);

    function setUp() public {
        initializeCoreContracts();
        mockToken = new ERC20Mock();
        hypurrfiPool = IHypurrfiPool(hypurrfiPoolAddress);

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
        HypurrfiDataTypes.ReserveData memory reserveData = HypurrfiDataTypes
            .ReserveData({
                configuration: HypurrfiDataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined
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
            address(hypurrfiPool),
            abi.encodeWithSelector(
                IHypurrfiPool(hypurrfiPool).getReserveData.selector
            ),
            abi.encode(reserveData)
        );
        ark = new HypurrfiArk(address(hypurrfiPool), rewardsController, params);
        nextArk = new HypurrfiArk(
            address(hypurrfiPool),
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
        HypurrfiDataTypes.ReserveData memory reserveData = HypurrfiDataTypes
            .ReserveData({
                configuration: HypurrfiDataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined
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
            address(hypurrfiPool),
            abi.encodeWithSelector(
                IHypurrfiPool(hypurrfiPool).getReserveData.selector
            ),
            abi.encode(reserveData)
        );
        ark = new HypurrfiArk(address(hypurrfiPool), rewardsController, params);
        assertEq(address(ark.hypurrfiPool()), address(hypurrfiPool));
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
            address(hypurrfiPool),
            abi.encodeWithSelector(
                hypurrfiPool.supply.selector,
                address(mockToken),
                amount,
                address(this),
                0
            ),
            abi.encode()
        );

        vm.expectCall(
            address(hypurrfiPool),
            abi.encodeWithSelector(
                hypurrfiPool.supply.selector,
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
            address(hypurrfiPool),
            abi.encodeWithSelector(
                hypurrfiPool.withdraw.selector,
                address(mockToken),
                amount,
                address(ark)
            ),
            abi.encode(amount)
        );

        vm.expectCall(
            address(hypurrfiPool),
            abi.encodeWithSelector(
                hypurrfiPool.withdraw.selector,
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
}
