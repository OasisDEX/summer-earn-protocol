// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {DataTypes} from "../../src/interfaces/aave-v3/DataTypes.sol";

contract AaveV3ArkTest is Test, IArkEvents {
    AaveV3Ark public ark;
    AaveV3Ark public nextArk;
    IProtocolAccessManager accessManager;
    IConfigurationManager configurationManager;

    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    address public constant aaveV3PoolAddress =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public aaveAddressProvider =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public aaveV3DataProvider =
        0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
    IPoolV3 public aaveV3Pool;
    ERC20Mock public mockToken;

    function setUp() public {
        mockToken = new ERC20Mock();
        aaveV3Pool = IPoolV3(aaveV3PoolAddress);

        accessManager = new ProtocolAccessManager(governor);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            maxAllocation: type(uint256).max
        });
        DataTypes.ReserveData memory reserveData = DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined and 0 is a placeholder
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
            abi.encodeWithSelector(
                IPoolV3(aaveV3Pool).ADDRESSES_PROVIDER.selector
            ),
            abi.encode(aaveAddressProvider)
        );
        vm.mockCall(
            address(aaveAddressProvider),
            abi.encodeWithSelector(
                IPoolAddressesProvider(aaveAddressProvider)
                    .getPoolDataProvider
                    .selector
            ),
            abi.encode(aaveV3DataProvider)
        );
        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).getReserveData.selector),
            abi.encode(reserveData)
        );
        ark = new AaveV3Ark(address(aaveV3Pool), params);
        nextArk = new AaveV3Ark(address(aaveV3Pool), params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        nextArk.grantCommanderRole(commander);
        vm.stopPrank();
    }

    function testConstructor() public {
        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            maxAllocation: type(uint256).max
        });
        DataTypes.ReserveData memory reserveData = DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0), // Assuming ReserveConfigurationMap is already defined and 0 is a placeholder
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
            abi.encodeWithSelector(
                IPoolV3(aaveV3Pool).ADDRESSES_PROVIDER.selector
            ),
            abi.encode(aaveAddressProvider)
        );
        vm.mockCall(
            address(aaveAddressProvider),
            abi.encodeWithSelector(
                IPoolAddressesProvider(aaveAddressProvider)
                    .getPoolDataProvider
                    .selector
            ),
            abi.encode(aaveV3DataProvider)
        );
        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).getReserveData.selector),
            abi.encode(reserveData)
        );
        ark = new AaveV3Ark(address(aaveV3Pool), params);
        assertEq(address(ark.aaveV3Pool()), address(aaveV3Pool));
        assertEq(address(ark.aaveV3DataProvider()), aaveV3DataProvider);

        assertEq(address(ark.token()), address(mockToken));
        assertEq(ark.maxAllocation(), type(uint256).max);
        assertEq(ark.aToken(), address(0));
    }

    function testBoard() public {
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
        ark.board(amount);
    }

    function testDisembark() public {
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
        ark.disembark(amount);
    }
}
