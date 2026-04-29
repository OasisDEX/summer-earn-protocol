// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {ProtectedMulticall} from "../../src/contracts/ProtectedMulticall.sol";
import {IFleetCommanderErrors} from "../../src/errors/IFleetCommanderErrors.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {FleetCommanderInstitutionalTestBase} from "../fleets/FleetCommanderInstitutionalTestBase.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

// Note: Assumes FleetCommanderInstitutionalTestBase has been updated to remove "Whitelist" from names
contract InstitutionalIntegrationTest is FleetCommanderInstitutionalTestBase {
    using PercentageUtils for uint256;

    struct DeployedSystem {
        address user;
        address usdc;
        FleetCommanderWhitelist fleet;
        AdmiralsQuartersWhitelist aq;
    }

    // Custom errors from the unified FleetCommanderWhitelist
    error FleetCommanderDirectDepositsClosed();
    error FleetCommanderDirectExitsClosed();
    error FleetCommanderTransfersDisabled();

    /**
     * @dev Deploys the unified architecture.
     * @param isGatewayOpen If true, allows users to bypass AQ and interact with Fleet directly (if whitelisted).
     */
    function _deploy(
        address user,
        bool isGatewayOpen
    ) internal returns (DeployedSystem memory deployedSystem) {
        _setupCore();

        address usdc = address(new MockERC20());

        FleetCommanderWhitelist fleet = new FleetCommanderWhitelist(
            _fleetParams(
                usdc,
                "USDC Fleet",
                "iUSDC",
                uint256(0).fromIntegerPercentage(),
                isGatewayOpen
            )
        );

        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(fleet));

        AdmiralsQuartersWhitelist aq = new AdmiralsQuartersWhitelist(
            address(0x111111125421cA6dc452d289314280a0f8842A65),
            address(configurationManager),
            address(accessManager),
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        // 1. Grant Operator Role to AQ on the Fleet
        vm.startPrank(governor);
        accessManager.grantOperatorRole(address(fleet), address(aq));

        // 2. Grant Whitelist Manager Role to the Governor (or test contract) to manage the global WL
        accessManager.grantWhitelistManagerRole(governor);
        vm.stopPrank();

        deployedSystem = DeployedSystem({
            user: user,
            usdc: usdc,
            fleet: fleet,
            aq: aq
        });

        vm.label(address(deployedSystem.user), "user");
        vm.label(address(deployedSystem.usdc), "usdc");
        vm.label(address(deployedSystem.fleet), "fleet");
        vm.label(address(deployedSystem.aq), "aq");
        vm.label(address(harborCommand), "harborCommand");
    }

    /**
     * @dev Centralized whitelisting. Only hitting the Access Manager V2.
     */
    function _setWhitelisted(
        address context,
        address account,
        bool allowed
    ) internal {
        vm.prank(governor);
        accessManager.setWhitelisted(context, account, allowed);
    }

    function _depositViaAQ(
        DeployedSystem memory sys,
        uint256 assets
    ) internal returns (uint256 shares) {
        deal(sys.usdc, sys.user, assets);
        vm.startPrank(sys.user);
        IERC20(sys.usdc).approve(address(sys.aq), type(uint256).max);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            sys.aq.depositTokens,
            (IERC20(sys.usdc), assets)
        );
        calls[1] = abi.encodeWithSelector(
            sys.aq.enterFleet.selector,
            address(sys.fleet),
            assets,
            sys.user
        );

        sys.aq.multicall(calls);
        vm.stopPrank();
        shares = IERC20(address(sys.fleet)).balanceOf(sys.user);
    }

    function _exitViaAQ(
        DeployedSystem memory sys,
        uint256 assets
    ) internal returns (uint256 sharesBurned) {
        uint256 expectedShares = sys.fleet.previewWithdraw(
            assets == 0 ? sys.fleet.maxWithdraw(sys.user) : assets
        );

        vm.startPrank(sys.user);
        IERC20(address(sys.fleet)).approve(address(sys.aq), type(uint256).max);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            sys.aq.exitFleet.selector,
            address(sys.fleet),
            assets
        );
        calls[1] = abi.encodeCall(sys.aq.withdrawTokens, (IERC20(sys.usdc), 0));

        sys.aq.multicall(calls);
        vm.stopPrank();
        sharesBurned = expectedShares;
    }

    function _depositDirectFleet(
        DeployedSystem memory sys,
        uint256 assets
    ) internal returns (uint256 shares) {
        deal(sys.usdc, sys.user, assets);
        vm.startPrank(sys.user);
        IERC20(sys.usdc).approve(address(sys.fleet), type(uint256).max);
        shares = sys.fleet.deposit(assets, sys.user);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     NORMAL OPERATION (INSTITUTIONAL FLOW)
    //////////////////////////////////////////////////////////////*/

    function test_EndToEnd_NormalInstitutionalFlow() public {
        address user = address(0xBEEF);

        // 1. Deploy with Fleet Gateway CLOSED (isGatewayOpen = false)
        DeployedSystem memory sys = _deploy(user, false);

        // 2. User is NOT whitelisted yet. Attempting to use AQ should fail at the multicall level.
        deal(sys.usdc, user, 100000);
        vm.startPrank(user);
        IERC20(sys.usdc).approve(address(sys.aq), type(uint256).max);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            sys.aq.depositTokens,
            (IERC20(sys.usdc), 100000)
        );
        calls[1] = abi.encodeWithSelector(
            sys.aq.enterFleet.selector,
            address(sys.fleet),
            100000,
            user
        );

        // Expect revert MUST be exactly here, right before the multicall
        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(sys.fleet),
                user
            )
        );
        sys.aq.multicall(calls);
        vm.stopPrank();

        // 3. Admin whitelists the user for AQ and Fleet in AccessManager
        _setWhitelisted(address(sys.aq), user, true);
        _setWhitelisted(address(sys.fleet), user, true);

        // 4. User deposits via AQ. Because AQ has OPERATOR_ROLE, it bypasses the Fleet's closed gateway.
        uint256 shares = _depositViaAQ(sys, 500000);
        assertGt(shares, 0, "User should receive shares via AQ");

        // 5. User tries to deposit directly to the Fleet. This MUST fail because the gateway is closed.
        vm.startPrank(user);
        IERC20(sys.usdc).approve(address(sys.fleet), type(uint256).max);
        vm.expectRevert(FleetCommanderDirectDepositsClosed.selector);
        sys.fleet.deposit(10000, user);
        vm.stopPrank();

        // 6. User tries to transfer shares to a friend. This MUST fail because transfers are disabled by default.
        address friend = address(0xF00D);
        vm.prank(user);
        vm.expectRevert(FleetCommanderTransfersDisabled.selector);
        sys.fleet.transfer(friend, 1000);

        // 7. Admin enables transfers.
        vm.prank(governor);
        sys.fleet.setFleetTokenTransferability(true);

        // 8. User tries to transfer again. It MUST fail because the friend is not whitelisted.
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(sys.fleet),
                friend
            )
        );
        sys.fleet.transfer(friend, 1000);

        // 9. Admin whitelists the friend.
        _setWhitelisted(address(sys.fleet), friend, true);

        // 10. Transfer finally succeeds!
        vm.prank(user);
        sys.fleet.transfer(friend, 1000);
        assertEq(
            IERC20(address(sys.fleet)).balanceOf(friend),
            1000,
            "Transfer should succeed"
        );

        // 11. User exits via AQ. Success.
        uint256 burned = _exitViaAQ(sys, 100000);
        assertGt(burned, 0, "User should be able to exit via AQ");
    }
    /*//////////////////////////////////////////////////////////////
                     OPEN GATEWAY (DIRECT FLEET INTERACTION)
    //////////////////////////////////////////////////////////////*/

    function test_OpenGateway_DirectDeposit_SucceedsIfWhitelisted() public {
        address user = address(0xBEEF);

        // Deploy with Gateway OPEN
        DeployedSystem memory sys = _deploy(user, true);

        // Whitelist user
        _setWhitelisted(address(sys.fleet), user, true);

        // Direct deposit succeeds
        uint256 shares = _depositDirectFleet(sys, 500000);
        assertGt(shares, 0, "Direct deposit should mint shares");
    }

    function test_OpenGateway_DirectDeposit_RevertsIfNotWhitelisted() public {
        address user = address(0xBEEF);

        // Deploy with Gateway OPEN
        DeployedSystem memory sys = _deploy(user, true);

        // User is NOT whitelisted
        _setWhitelisted(address(sys.fleet), user, false);

        // Direct deposit fails on the whitelist check
        deal(sys.usdc, user, 100000);
        vm.startPrank(user);
        IERC20(sys.usdc).approve(address(sys.fleet), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(sys.fleet),
                user
            )
        );
        sys.fleet.deposit(100000, user);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     OPERATOR BYPASS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Operator_CanAlwaysTransfer_EvenIfDisabled() public {
        address user = address(0xBEEF);
        DeployedSystem memory sys = _deploy(user, false);

        _setWhitelisted(address(sys.aq), user, true);
        _setWhitelisted(address(sys.fleet), user, true);
        _depositViaAQ(sys, 500000);

        // The AQ (Operator) should be able to transfer tokens freely, even with transfers disabled globally.
        // E.g., moving shares during an exit routing
        uint256 aqBalanceBefore = IERC20(address(sys.fleet)).balanceOf(
            address(sys.aq)
        );

        // Prank user transferring to AQ (simulating a transferFrom by the Operator)
        vm.prank(user);
        IERC20(address(sys.fleet)).approve(address(sys.aq), 1000);

        vm.prank(address(sys.aq)); // Prank as the Operator
        bool success = sys.fleet.transferFrom(user, address(sys.aq), 1000);

        assertTrue(success, "Operator should bypass transfer restrictions");
        assertEq(
            IERC20(address(sys.fleet)).balanceOf(address(sys.aq)),
            aqBalanceBefore + 1000
        );
    }
}
