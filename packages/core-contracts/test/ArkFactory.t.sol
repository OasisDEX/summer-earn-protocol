// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/contracts/ArkFactory.sol";
import "../src/contracts/arks/AaveV3Ark.sol";
import "../src/types/ArkFactoryTypes.sol";
import "../src/errors/ArkFactoryErrors.sol";
import "../src/errors/ArkAccessControlErrors.sol";

contract ArkFactoryTest is Test {
    ArkFactory public arkFactory;
    address public governor = address(1);
    address public raft = address(2);
    address public aaveV3Pool = address(3);
    address public testToken = address(4);
    address public aaveAddressProvider = address(5);
    address public aaveV3DataProvider = address(6);

    function setUp() public {
        ArkFactoryParams memory params = ArkFactoryParams({
            governor: governor,
            raft: raft,
            aaveV3Pool: aaveV3Pool
        });
        arkFactory = new ArkFactory(params);
    }

    function testCreateAaveV3Ark() public {
        vm.prank(governor); // Set msg.sender to governor
        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).ADDRESSES_PROVIDER.selector),
            abi.encode(aaveAddressProvider)
        );
        vm.mockCall(
            address(aaveAddressProvider),
            abi.encodeWithSelector(IPoolAddressesProvider(aaveAddressProvider).getPoolDataProvider.selector),
            abi.encode(aaveV3DataProvider)
        );
        address newArk = arkFactory.createAaveV3Ark(testToken);

        assertTrue(newArk != address(0));
        AaveV3Ark ark = AaveV3Ark(newArk);
        address _token = address(ark.token());
        AccessControl accessControl = AccessControl(address(ark));

        assertEq(_token, testToken);
        assertTrue(accessControl.hasRole(ark.GOVERNOR_ROLE(), governor));
        assertEq(ark.raft(), raft);
    }

    function testSetRaft() public {
        address newRaft = address(5);

        vm.prank(governor); // Set msg.sender to governor
        arkFactory.setRaft(newRaft);

        assertEq(arkFactory.raft(), newRaft);
    }

    function testSetRaftRevertsWhenZeroAddress() public {
        vm.prank(governor); // Set msg.sender to governor
        vm.expectRevert(CannotSetRaftToZeroAddress.selector);
        arkFactory.setRaft(address(0));
    }

    function testSetGovernor() public {
        address newGovernor = address(6);

        vm.prank(governor); // Set msg.sender to governor
        arkFactory.setGovernor(newGovernor);

        assertEq(arkFactory.governor(), newGovernor);
    }

    function testOnlyGovernorCanSetRaft() public {
        address newRaft = address(5);

        vm.prank(address(7)); // Set msg.sender to a non-governor address
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, address(7))
        );
        arkFactory.setRaft(newRaft);
    }

    function testOnlyGovernorCanSetGovernor() public {
        address newGovernor = address(6);

        vm.prank(address(7)); // Set msg.sender to a non-governor address
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, address(7))
        );
        arkFactory.setGovernor(newGovernor);
    }
}
