// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {BaseArkParams, AaveV3Ark, IPoolV3, IPoolAddressesProvider} from "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract AaveV3ArkTest is Test, IArkEvents {
    AaveV3Ark public ark;
    AaveV3Ark public nextArk;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
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

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManagerImp = new ConfigurationManager();
        ConfigurationManager configurationManager = ConfigurationManager(
            Clones.clone(address(configurationManagerImp))
        );
        configurationManager.initialize(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft
            })
        );

        BaseArkParams memory params = BaseArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            maxAllocation: 1000000000
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

        bytes memory additionalParams = abi.encode(address(aaveV3Pool));
        AaveV3Ark arkImp = new AaveV3Ark();

        ark = AaveV3Ark(Clones.clone(address(arkImp)));
        ark.initialize(params, additionalParams);

        nextArk = AaveV3Ark(Clones.clone(address(arkImp)));
        nextArk.initialize(params, additionalParams);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        nextArk.grantCommanderRole(commander);
        vm.stopPrank();
    }

    function testBoard() public {
        vm.prank(governor); // Set msg.sender to governor
        ark.grantCommanderRole(commander);

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
        vm.prank(governor); // Set msg.sender to governor
        ark.grantCommanderRole(commander);

        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.withdraw.selector,
                address(mockToken),
                amount,
                commander
            ),
            abi.encode(amount)
        );

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.withdraw.selector,
                address(mockToken),
                amount,
                commander
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
