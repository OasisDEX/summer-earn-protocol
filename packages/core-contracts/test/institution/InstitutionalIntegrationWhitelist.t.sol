// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWhitelistInstitutionalTestBase} from "../fleets/FleetCommanderWhitelistInstitutionalTestBase.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {ProtectedMulticallWhitelist} from "../../src/contracts/ProtectedMulticallWhitelist.sol";

contract InstitutionalIntegrationWhitelistTest is
    FleetCommanderWhitelistInstitutionalTestBase
{
    using PercentageUtils for uint256;

    enum WhitelistMode {
        BothOpen,
        AQOpen_FleetOnlyAQ,
        FleetOnlyUser_NoAQ,
        AQUser_FleetOnlyAQ
    }

    struct Deployed {
        address user;
        address usdc;
        FleetCommanderWhitelist fleet;
        AdmiralsQuartersWhitelist aq;
    }

    function _deploy(address user) internal returns (Deployed memory d) {
        _setupCore();

        address usdc = address(new MockERC20());

        FleetCommanderWhitelist fleet = new FleetCommanderWhitelist(
            _fleetParams(
                usdc,
                "USDC Fleet",
                "iUSDC",
                uint256(0).fromIntegerPercentage()
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

        d = Deployed({user: user, usdc: usdc, fleet: fleet, aq: aq});
    }

    function _configureWhitelists(
        WhitelistMode mode,
        Deployed memory d
    ) internal {
        vm.startPrank(governor);
        if (mode == WhitelistMode.BothOpen) {
            d.fleet.setWhitelisted(address(0), true);
            d.aq.setWhitelisted(address(0), true);
        } else if (mode == WhitelistMode.AQOpen_FleetOnlyAQ) {
            d.fleet.setWhitelisted(address(d.aq), true);
            d.aq.setWhitelisted(address(0), true);
        } else if (mode == WhitelistMode.FleetOnlyUser_NoAQ) {
            d.fleet.setWhitelisted(d.user, true);
        } else if (mode == WhitelistMode.AQUser_FleetOnlyAQ) {
            d.fleet.setWhitelisted(address(d.aq), true);
            d.aq.setWhitelisted(d.user, true);
        }
        vm.stopPrank();
    }

    function _depositViaAQ(
        Deployed memory d,
        uint256 assets
    ) internal returns (uint256 shares) {
        // user approves AQ and executes multicall: depositTokens -> enterFleet
        deal(d.usdc, d.user, assets);
        vm.startPrank(d.user);
        IERC20(d.usdc).approve(address(d.aq), type(uint256).max);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(d.aq.depositTokens, (IERC20(d.usdc), assets));
        calls[1] = abi.encodeWithSelector(
            d.aq.enterFleet.selector,
            address(d.fleet),
            assets,
            d.user
        );
        d.aq.multicall(calls);
        vm.stopPrank();
        shares = IERC20(address(d.fleet)).balanceOf(d.user);
    }

    function _depositDirect(
        Deployed memory d,
        uint256 assets
    ) internal returns (uint256 shares) {
        deal(d.usdc, d.user, assets);
        vm.startPrank(d.user);
        IERC20(d.usdc).approve(address(d.fleet), type(uint256).max);
        shares = d.fleet.deposit(assets, d.user);
        vm.stopPrank();
    }

    function _mintDirect(
        Deployed memory d,
        uint256 targetShares
    ) internal returns (uint256 assetsPaid) {
        // preview assets needed and approve
        assetsPaid = d.fleet.previewMint(targetShares);
        deal(d.usdc, d.user, assetsPaid);
        vm.startPrank(d.user);
        IERC20(d.usdc).approve(address(d.fleet), type(uint256).max);
        d.fleet.mint(targetShares, d.user);
        vm.stopPrank();
    }

    function _withdrawDirect(
        Deployed memory d,
        uint256 assets
    ) internal returns (uint256 sharesBurned) {
        uint256 balBefore = IERC20(d.usdc).balanceOf(d.user);
        vm.prank(d.user);
        sharesBurned = d.fleet.withdraw(assets, d.user, d.user);
        uint256 balAfter = IERC20(d.usdc).balanceOf(d.user);
        assertGt(balAfter, balBefore, "withdraw did not transfer assets");
    }

    function _redeemDirect(
        Deployed memory d,
        uint256 shares
    ) internal returns (uint256 assetsOut) {
        uint256 balBefore = IERC20(d.usdc).balanceOf(d.user);
        vm.prank(d.user);
        assetsOut = d.fleet.redeem(shares, d.user, d.user);
        uint256 balAfter = IERC20(d.usdc).balanceOf(d.user);
        assertGt(balAfter, balBefore, "redeem did not transfer assets");
    }

    function _exitViaAQ(
        Deployed memory d,
        uint256 assets
    ) internal returns (uint256 sharesBurned) {
        // user must approve AQ to spend fleet shares; AQ will withdraw to itself, then forward underlying to user
        uint256 beforeBal = IERC20(d.usdc).balanceOf(d.user);
        uint256 expectedShares = d.fleet.previewWithdraw(
            assets == 0 ? d.fleet.maxWithdraw(d.user) : assets
        );
        vm.startPrank(d.user);
        IERC20(address(d.fleet)).approve(address(d.aq), type(uint256).max);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            d.aq.exitFleet.selector,
            address(d.fleet),
            assets
        );
        // withdraw all of the underlying the AQ received from exit to the user
        calls[1] = abi.encodeCall(d.aq.withdrawTokens, (IERC20(d.usdc), 0));
        d.aq.multicall(calls);
        vm.stopPrank();
        uint256 afterBal = IERC20(d.usdc).balanceOf(d.user);
        assertGt(afterBal, beforeBal, "AQ exit did not pay assets");
        sharesBurned = expectedShares;
    }

    function test_EndToEnd_DepositEnter_UsingRegistry() public {
        _setupCore();

        address usdc = address(new MockERC20());

        // Deploy FleetCommanderWhitelist
        FleetCommanderWhitelist fleet = new FleetCommanderWhitelist(
            _fleetParams(
                usdc,
                "USDC Fleet",
                "iUSDC",
                uint256(0).fromIntegerPercentage()
            )
        );

        // Enlist Fleet in Harbor
        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(fleet));

        // Deploy AdmiralsQuartersWhitelist
        AdmiralsQuartersWhitelist aq = new AdmiralsQuartersWhitelist(
            address(0x111111125421cA6dc452d289314280a0f8842A65),
            address(configurationManager),
            address(accessManager),
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        // Open whitelists
        vm.startPrank(governor);
        fleet.setWhitelisted(address(aq), true);
        aq.setWhitelisted(address(0xBEEF), true);
        vm.stopPrank();

        // Register institution
        bytes32 id = keccak256("inst-reg-test");
        _register(id, address(aq));

        // Deal tokens to user and approve AQ
        address user = address(0xBEEF);
        deal(usdc, user, 1_000_000);
        vm.startPrank(user);
        IERC20(usdc).approve(address(aq), type(uint256).max);

        // Deposit and enter via AQ multicall
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(aq.depositTokens, (IERC20(usdc), 500_000));
        calls[1] = abi.encodeWithSelector(
            aq.enterFleet.selector,
            address(fleet),
            500_000,
            user
        );
        aq.multicall(calls);
        vm.stopPrank();

        // Assert user received shares
        uint256 shares = IERC20(address(fleet)).balanceOf(user);
        assertGt(shares, 0, "User should receive shares");
    }

    function test_Flow_DepositDirect_WithdrawDirect_FleetOnlyUser() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        _configureWhitelists(WhitelistMode.FleetOnlyUser_NoAQ, d);

        uint256 shares = _depositDirect(d, 500_000);
        assertGt(shares, 0, "deposit should mint shares");

        uint256 burned = _withdrawDirect(d, 200_000);
        assertGt(burned, 0, "withdraw should burn shares");
    }

    function test_Flow_MintDirect_RedeemDirect_BothOpen() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        _configureWhitelists(WhitelistMode.BothOpen, d);

        _mintDirect(d, 100_000);
        uint256 userShares = IERC20(address(d.fleet)).balanceOf(user);
        assertGt(userShares, 0, "mint should grant shares");

        uint256 half = userShares / 2;
        uint256 assetsOut = _redeemDirect(d, half);
        assertGt(assetsOut, 0, "redeem should return assets");
    }

    function test_Flow_DepositViaAQ_WithdrawDirect_AQOpen_FleetOnlyAQ() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        _configureWhitelists(WhitelistMode.AQOpen_FleetOnlyAQ, d);

        uint256 shares = _depositViaAQ(d, 500_000);
        assertGt(shares, 0, "AQ deposit should mint shares");

        uint256 burned = _withdrawDirect(d, 100_000);
        assertGt(burned, 0, "direct withdraw should burn shares");
    }

    function test_Flow_DepositViaAQ_ExitViaAQ_AQUser_FleetOnlyAQ() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        _configureWhitelists(WhitelistMode.AQUser_FleetOnlyAQ, d);

        uint256 shares = _depositViaAQ(d, 500_000);
        assertGt(shares, 0, "AQ deposit should mint shares");

        _exitViaAQ(d, 150_000);
    }

    function test_Flow_DepositDirect_ExitViaAQ_BothOpen() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        _configureWhitelists(WhitelistMode.BothOpen, d);

        uint256 shares = _depositDirect(d, 500_000);
        assertGt(shares, 0, "direct deposit should mint shares");

        _exitViaAQ(d, 150_000);
    }

    function test_Flow_DepositViaAQ_ExitViaAQ_BothOpen() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        _configureWhitelists(WhitelistMode.BothOpen, d);

        uint256 shares = _depositViaAQ(d, 400_000);
        assertGt(shares, 0, "AQ deposit should mint shares");

        _exitViaAQ(d, 200_000);
    }

    // Negative tests for ProtectedMulticallWhitelist and whitelist gating

    function test_AQ_Multicall_Reverts_When_UserNotWhitelisted() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        // AQ closed, user not whitelisted, fleet open shouldn't matter for AQ
        _configureWhitelists(WhitelistMode.FleetOnlyUser_NoAQ, d);

        bytes[] memory calls = new bytes[](0);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, user));
        d.aq.multicall(calls);
        vm.stopPrank();
    }

    function test_AQ_FunctionDirectCall_Reverts_NotMulticall() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        // Whitelist user on AQ to isolate onlyMulticall guard
        vm.prank(governor);
        d.aq.setWhitelisted(user, true);

        deal(d.usdc, user, 1000);
        vm.startPrank(user);
        IERC20(d.usdc).approve(address(d.aq), type(uint256).max);
        vm.expectRevert(ProtectedMulticallWhitelist.NotMulticall.selector);
        d.aq.depositTokens(IERC20(d.usdc), 1000);
        vm.stopPrank();
    }

    function test_AQ_NestedMulticall_Reverts_MulticallAlreadyInProgress() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        // Allow user to use multicall
        vm.prank(governor);
        d.aq.setWhitelisted(user, true);

        // Build inner multicall payload (empty)
        bytes[] memory empty = new bytes[](0);
        bytes[] memory outer = new bytes[](1);
        outer[0] = abi.encodeWithSelector(d.aq.multicall.selector, empty);

        vm.startPrank(user);
        vm.expectRevert(ProtectedMulticallWhitelist.MulticallAlreadyInProgress.selector);
        d.aq.multicall(outer);
        vm.stopPrank();
    }

    function test_Fleet_Direct_Deposit_Reverts_When_UserNotWhitelisted() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        // Fleet only trusts AQ; user is not whitelisted
        vm.prank(governor);
        d.fleet.setWhitelisted(address(d.aq), true);

        deal(d.usdc, user, 1000);
        vm.startPrank(user);
        IERC20(d.usdc).approve(address(d.fleet), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, user));
        d.fleet.deposit(1000, user);
        vm.stopPrank();
    }

    function test_AQ_ExitFleet_DirectCall_Reverts_NotMulticall() public {
        address user = address(0xBEEF);
        Deployed memory d = _deploy(user);
        // Whitelist user and AQ so deposit via AQ works, then try calling exitFleet directly
        vm.startPrank(governor);
        d.aq.setWhitelisted(user, true);
        d.fleet.setWhitelisted(address(d.aq), true);
        vm.stopPrank();

        // fund and enter via AQ properly
        _depositViaAQ(d, 1000);

        // now user attempts to call exitFleet directly: should revert NotMulticall
        vm.startPrank(user);
        IERC20(address(d.fleet)).approve(address(d.aq), type(uint256).max);
        vm.expectRevert(ProtectedMulticallWhitelist.NotMulticall.selector);
        d.aq.exitFleet(address(d.fleet), 100);
        vm.stopPrank();
    }
}
