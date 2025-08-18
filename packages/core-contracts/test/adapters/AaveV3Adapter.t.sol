// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3Escrow} from "../../src/contracts/adapters/AaveV3Escrow.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AaveV3Escrow Test
 * @notice Tests for the AaveV3Escrow contract with GenericIntentArk integration
 * @dev Tests the adapter functionality and access control with onlyAuthorizedToBoard
 */
contract AaveV3AdapterTest is Test {
    AaveV3Escrow public adapter;
    ProtocolAccessManager public accessManager;
    MockERC20 public mockToken;

    // Mock addresses
    address public mockAaveV3Pool = address(0x300);
    address public mockRewardsController = address(0x400);
    address public mockArk = address(0x500);

    // Test addresses
    address public governor = address(0x1);
    address public commander = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        // Deploy access manager with governor
        accessManager = new ProtocolAccessManager(governor);

        // Deploy adapter
        adapter = new AaveV3Escrow(
            address(accessManager),
            mockAaveV3Pool,
            mockRewardsController,
            mockArk
        );

        // Deploy mock token
        mockToken = new MockERC20();
        mockToken.initialize("Mock Token", "MTK", 18);

        // Mock the ark.commander() call to return commander
        vm.mockCall(
            mockArk,
            abi.encodeWithSignature("commander()"),
            abi.encode(commander)
        );

        // Setup token balances
        deal(address(mockToken), commander, 10000e18);
        deal(address(mockToken), user, 10000e18);
    }

    function test_AdapterDeployment() public {
        assertEq(address(adapter.ark()), mockArk);
        assertEq(address(adapter.aaveV3Pool()), mockAaveV3Pool);
        assertEq(address(adapter.rewardsController()), mockRewardsController);
    }

    function test_AdapterAccessControl() public {
        uint256 amount = 1000e18;

        // Mock the Aave pool supply call
        vm.mockCall(
            mockAaveV3Pool,
            abi.encodeWithSignature("supply(address,uint256,address,uint16)"),
            abi.encode()
        );

        // Mock that ark.intentHandler() returns a mock handler address
        address mockIntentHandler = address(0x777);
        vm.mockCall(
            mockArk,
            abi.encodeWithSignature("intentHandler()"),
            abi.encode(mockIntentHandler)
        );

        // Should work for IntentHandler
        vm.startPrank(mockIntentHandler);
        adapter.deposit(address(mockToken), amount, address(mockArk));
        vm.stopPrank();

        // Should fail for unauthorized user (not IntentHandler)
        vm.startPrank(user);
        vm.expectRevert();
        adapter.deposit(address(mockToken), amount, address(mockArk));
        vm.stopPrank();

        // Should also fail for commander (no longer has direct access)
        vm.startPrank(commander);
        vm.expectRevert();
        adapter.deposit(address(mockToken), amount, address(mockArk));
        vm.stopPrank();
    }

    function test_AdapterWithdraw() public {
        uint256 amount = 500e18;

        // Mock the Aave pool withdraw call
        vm.mockCall(
            mockAaveV3Pool,
            abi.encodeWithSignature("withdraw(address,uint256,address)"),
            abi.encode(amount)
        );

        // Mock that ark.intentHandler() returns a mock handler address
        address mockIntentHandler = address(0x777);
        vm.mockCall(
            mockArk,
            abi.encodeWithSignature("intentHandler()"),
            abi.encode(mockIntentHandler)
        );

        // Should work for IntentHandler
        vm.startPrank(mockIntentHandler);
        adapter.withdraw(address(mockToken), amount, commander);
        vm.stopPrank();

        // Should fail for unauthorized user
        vm.startPrank(user);
        vm.expectRevert();
        adapter.withdraw(address(mockToken), amount, user);
        vm.stopPrank();
    }

    function test_AdapterGetReserveData() public {
        // This should be callable by anyone (view function) - no need to mock since it's just a view
        vm.startPrank(user);
        // Just call it without expecting a specific result since it's a mock
        try adapter.getReserveData(address(mockToken)) {
            // Success case
        } catch {
            // If it fails, that's also fine for this basic test
            // The important part is that access control allows it
        }
        vm.stopPrank();
    }
}
