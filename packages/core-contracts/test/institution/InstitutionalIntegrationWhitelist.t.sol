// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWhitelistInstitutionalTestBase} from "../fleets/FleetCommanderWhitelistInstitutionalTestBase.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {ProtectedMulticallWhitelist} from "../../src/contracts/ProtectedMulticallWhitelist.sol";
import {IFleetCommanderErrors} from "../../src/errors/IFleetCommanderErrors.sol";

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

    struct DeployedSytem {
        address user;
        address usdc;
        FleetCommanderWhitelist fleet;
        AdmiralsQuartersWhitelist aq;
    }

    function _deploy(
        address user
    ) internal returns (DeployedSytem memory deployedSystem) {
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

        deployedSystem = DeployedSytem({
            user: user,
            usdc: usdc,
            fleet: fleet,
            aq: aq
        });
    }

    function _configureWhitelists(
        WhitelistMode mode,
        DeployedSytem memory deployedSystem
    ) internal {
        vm.startPrank(governor);
        if (mode == WhitelistMode.BothOpen) {
            deployedSystem.fleet.setWhitelisted(address(0), true);
            deployedSystem.aq.setWhitelisted(address(0), true);
        } else if (mode == WhitelistMode.AQOpen_FleetOnlyAQ) {
            deployedSystem.fleet.setWhitelisted(
                address(deployedSystem.aq),
                true
            );
            deployedSystem.aq.setWhitelisted(address(0), true);
        } else if (mode == WhitelistMode.FleetOnlyUser_NoAQ) {
            deployedSystem.fleet.setWhitelisted(deployedSystem.user, true);
        } else if (mode == WhitelistMode.AQUser_FleetOnlyAQ) {
            deployedSystem.fleet.setWhitelisted(
                address(deployedSystem.aq),
                true
            );
            deployedSystem.aq.setWhitelisted(deployedSystem.user, true);
        }
        vm.stopPrank();
    }

    function _depositViaAQ(
        DeployedSytem memory deployedSystem,
        uint256 assets
    ) internal returns (uint256 shares) {
        // user approves AQ and executes multicall: depositTokens -> enterFleet
        deal(deployedSystem.usdc, deployedSystem.user, assets);
        vm.startPrank(deployedSystem.user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.aq),
            type(uint256).max
        );
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            deployedSystem.aq.depositTokens,
            (IERC20(deployedSystem.usdc), assets)
        );
        calls[1] = abi.encodeWithSelector(
            deployedSystem.aq.enterFleet.selector,
            address(deployedSystem.fleet),
            assets,
            deployedSystem.user
        );
        deployedSystem.aq.multicall(calls);
        vm.stopPrank();
        shares = IERC20(address(deployedSystem.fleet)).balanceOf(
            deployedSystem.user
        );
    }

    function _depositDirectFleet(
        DeployedSytem memory deployedSystem,
        uint256 assets
    ) internal returns (uint256 shares) {
        deal(deployedSystem.usdc, deployedSystem.user, assets);
        vm.startPrank(deployedSystem.user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.fleet),
            type(uint256).max
        );
        shares = deployedSystem.fleet.deposit(assets, deployedSystem.user);
        vm.stopPrank();
    }

    function _mintDirect(
        DeployedSytem memory deployedSystem,
        uint256 targetShares
    ) internal returns (uint256 assetsPaid) {
        // preview assets needed and approve
        assetsPaid = deployedSystem.fleet.previewMint(targetShares);
        deal(deployedSystem.usdc, deployedSystem.user, assetsPaid);
        vm.startPrank(deployedSystem.user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.fleet),
            type(uint256).max
        );
        deployedSystem.fleet.mint(targetShares, deployedSystem.user);
        vm.stopPrank();
    }

    function _withdrawDirect(
        DeployedSytem memory deployedSystem,
        uint256 assets
    ) internal returns (uint256 sharesBurned) {
        uint256 balBefore = IERC20(deployedSystem.usdc).balanceOf(
            deployedSystem.user
        );
        vm.prank(deployedSystem.user);
        sharesBurned = deployedSystem.fleet.withdraw(
            assets,
            deployedSystem.user,
            deployedSystem.user
        );
        uint256 balAfter = IERC20(deployedSystem.usdc).balanceOf(
            deployedSystem.user
        );
        assertGt(balAfter, balBefore, "withdraw did not transfer assets");
    }

    function _redeemDirect(
        DeployedSytem memory deployedSystem,
        uint256 shares
    ) internal returns (uint256 assetsOut) {
        uint256 balBefore = IERC20(deployedSystem.usdc).balanceOf(
            deployedSystem.user
        );
        vm.prank(deployedSystem.user);
        assetsOut = deployedSystem.fleet.redeem(
            shares,
            deployedSystem.user,
            deployedSystem.user
        );
        uint256 balAfter = IERC20(deployedSystem.usdc).balanceOf(
            deployedSystem.user
        );
        assertGt(balAfter, balBefore, "redeem did not transfer assets");
    }

    function _exitViaAQ(
        DeployedSytem memory deployedSystem,
        uint256 assets
    ) internal returns (uint256 sharesBurned) {
        // user must approve AQ to spend fleet shares; AQ will withdraw to itself, then forward underlying to user
        uint256 beforeBal = IERC20(deployedSystem.usdc).balanceOf(
            deployedSystem.user
        );
        uint256 expectedShares = deployedSystem.fleet.previewWithdraw(
            assets == 0
                ? deployedSystem.fleet.maxWithdraw(deployedSystem.user)
                : assets
        );
        vm.startPrank(deployedSystem.user);
        IERC20(address(deployedSystem.fleet)).approve(
            address(deployedSystem.aq),
            type(uint256).max
        );
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            deployedSystem.aq.exitFleet.selector,
            address(deployedSystem.fleet),
            assets
        );
        // withdraw all of the underlying the AQ received from exit to the user
        calls[1] = abi.encodeCall(
            deployedSystem.aq.withdrawTokens,
            (IERC20(deployedSystem.usdc), 0)
        );
        deployedSystem.aq.multicall(calls);
        vm.stopPrank();
        uint256 afterBal = IERC20(deployedSystem.usdc).balanceOf(
            deployedSystem.user
        );
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
        aq.setWhitelisted(address(0), true);
        fleet.setWhitelisted(address(aq), true);
        fleet.setWhitelisted(address(0xBEEF), true);
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
        DeployedSytem memory deployedSystem = _deploy(user);
        _configureWhitelists(WhitelistMode.FleetOnlyUser_NoAQ, deployedSystem);

        uint256 shares = _depositDirectFleet(deployedSystem, 500_000);
        assertGt(shares, 0, "deposit should mint shares");

        uint256 burned = _withdrawDirect(deployedSystem, 200_000);
        assertGt(burned, 0, "withdraw should burn shares");
    }

    function test_Flow_MintDirect_RedeemDirect_BothOpen() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        _configureWhitelists(WhitelistMode.BothOpen, deployedSystem);

        _mintDirect(deployedSystem, 100_000);
        uint256 userShares = IERC20(address(deployedSystem.fleet)).balanceOf(
            user
        );
        assertGt(userShares, 0, "mint should grant shares");

        uint256 half = userShares / 2;
        uint256 assetsOut = _redeemDirect(deployedSystem, half);
        assertGt(assetsOut, 0, "redeem should return assets");
    }

    function test_Flow_DepositViaAQ_WithdrawDirect_AQOpen_FleetOnlyAQ() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        _configureWhitelists(WhitelistMode.AQOpen_FleetOnlyAQ, deployedSystem);

        // Fleet only trusts AQ, not user as receiver -> deposit via AQ should revert on receiver whitelist
        deal(deployedSystem.usdc, deployedSystem.user, 500_000);
        vm.startPrank(deployedSystem.user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.aq),
            type(uint256).max
        );
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            deployedSystem.aq.depositTokens,
            (IERC20(deployedSystem.usdc), 500_000)
        );
        calls[1] = abi.encodeWithSelector(
            deployedSystem.aq.enterFleet.selector,
            address(deployedSystem.fleet),
            500_000,
            deployedSystem.user
        );
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, deployedSystem.user)
        );
        deployedSystem.aq.multicall(calls);
        vm.stopPrank();
    }

    function test_Flow_DepositViaAQ_ExitViaAQ_AQUser_FleetOnlyAQ() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        _configureWhitelists(WhitelistMode.AQUser_FleetOnlyAQ, deployedSystem);

        // Fleet only trusts AQ as caller, not user as receiver -> deposit via AQ should revert
        deal(deployedSystem.usdc, deployedSystem.user, 500_000);
        vm.startPrank(deployedSystem.user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.aq),
            type(uint256).max
        );
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            deployedSystem.aq.depositTokens,
            (IERC20(deployedSystem.usdc), 500_000)
        );
        calls[1] = abi.encodeWithSelector(
            deployedSystem.aq.enterFleet.selector,
            address(deployedSystem.fleet),
            500_000,
            deployedSystem.user
        );
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, deployedSystem.user)
        );
        deployedSystem.aq.multicall(calls);
        vm.stopPrank();
    }

    function test_Flow_DepositDirect_ExitViaAQ_BothOpen() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        _configureWhitelists(WhitelistMode.BothOpen, deployedSystem);

        uint256 shares = _depositDirectFleet(deployedSystem, 500_000);
        assertGt(shares, 0, "direct deposit should mint shares");

        _exitViaAQ(deployedSystem, 150_000);
    }

    function test_Flow_DepositViaAQ_ExitViaAQ_BothOpen() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        _configureWhitelists(WhitelistMode.BothOpen, deployedSystem);

        uint256 shares = _depositViaAQ(deployedSystem, 400_000);
        assertGt(shares, 0, "AQ deposit should mint shares");

        _exitViaAQ(deployedSystem, 200_000);
    }

    function test_Flow_DepositViaAQ_Succeeds_When_FleetWhitelistsAQAndUser()
        public
    {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        // Fleet must whitelist both AQ (caller) and user (receiver)
        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(address(deployedSystem.aq), true);
        deployedSystem.fleet.setWhitelisted(user, true);
        deployedSystem.aq.setWhitelisted(user, true);
        vm.stopPrank();

        uint256 shares = _depositViaAQ(deployedSystem, 123_000);
        assertGt(
            shares,
            0,
            "AQ deposit should mint shares when both are whitelisted"
        );
    }

    // Negative tests for ProtectedMulticallWhitelist and whitelist gating

    function test_AQ_Multicall_Reverts_When_UserNotWhitelisted() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        // AQ closed, user not whitelisted, fleet open shouldn't matter for AQ
        _configureWhitelists(WhitelistMode.FleetOnlyUser_NoAQ, deployedSystem);

        bytes[] memory calls = new bytes[](0);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, user));
        deployedSystem.aq.multicall(calls);
        vm.stopPrank();
    }

    function test_AQ_FunctionDirectCall_Reverts_NotMulticall() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        // Whitelist user on AQ to isolate onlyMulticall guard
        vm.prank(governor);
        deployedSystem.aq.setWhitelisted(user, true);

        deal(deployedSystem.usdc, user, 1000);
        vm.startPrank(user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.aq),
            type(uint256).max
        );
        vm.expectRevert(ProtectedMulticallWhitelist.NotMulticall.selector);
        deployedSystem.aq.depositTokens(IERC20(deployedSystem.usdc), 1000);
        vm.stopPrank();
    }

    function test_AQ_NestedMulticall_Reverts_MulticallAlreadyInProgress()
        public
    {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        // Allow user to use multicall
        vm.prank(governor);
        deployedSystem.aq.setWhitelisted(user, true);

        // Build inner multicall payload (empty)
        bytes[] memory empty = new bytes[](0);
        bytes[] memory outer = new bytes[](1);
        outer[0] = abi.encodeWithSelector(
            deployedSystem.aq.multicall.selector,
            empty
        );

        vm.startPrank(user);
        vm.expectRevert(
            ProtectedMulticallWhitelist.MulticallAlreadyInProgress.selector
        );
        deployedSystem.aq.multicall(outer);
        vm.stopPrank();
    }

    function test_Fleet_Direct_Deposit_Reverts_When_UserNotWhitelisted()
        public
    {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        // Fleet only trusts AQ; user is not whitelisted
        vm.prank(governor);
        deployedSystem.fleet.setWhitelisted(address(deployedSystem.aq), true);

        deal(deployedSystem.usdc, user, 1000);
        vm.startPrank(user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.fleet),
            type(uint256).max
        );
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, user));
        deployedSystem.fleet.deposit(1000, user);
        vm.stopPrank();
    }

    function test_AQ_ExitFleet_DirectCall_Reverts_NotMulticall() public {
        address user = address(0xBEEF);
        DeployedSytem memory deployedSystem = _deploy(user);
        // Whitelist user and AQ so deposit via AQ works, then try calling exitFleet directly
        vm.startPrank(governor);
        deployedSystem.aq.setWhitelisted(user, true);
        deployedSystem.fleet.setWhitelisted(user, true);
        deployedSystem.fleet.setWhitelisted(address(deployedSystem.aq), true);
        vm.stopPrank();

        // fund and enter via AQ properly
        _depositViaAQ(deployedSystem, 1000);

        // now user attempts to call exitFleet directly: should revert NotMulticall
        vm.startPrank(user);
        IERC20(address(deployedSystem.fleet)).approve(
            address(deployedSystem.aq),
            type(uint256).max
        );
        vm.expectRevert(ProtectedMulticallWhitelist.NotMulticall.selector);
        deployedSystem.aq.exitFleet(address(deployedSystem.fleet), 100);
        vm.stopPrank();
    }

    // ------------------------------------------------------------
    // ERC20 transfers: whitelist gating and transfersEnabled toggle
    // ------------------------------------------------------------

    function test_Transfer_Reverts_When_Disabled_EvenIfBothWhitelisted()
        public
    {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(alice);

        // Whitelist both sender and recipient; transfers disabled by default
        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(alice, true);
        deployedSystem.fleet.setWhitelisted(bob, true);
        vm.stopPrank();

        // Fund sender with shares
        _depositDirectFleet(deployedSystem, 500_000);

        vm.prank(alice);
        vm.expectRevert(
            IFleetCommanderErrors.FleetCommanderTransfersDisabled.selector
        );
        deployedSystem.fleet.transfer(bob, 100_000);
    }

    function test_Transfer_Reverts_When_Enabled_RecipientNotWhitelisted()
        public
    {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(alice);

        // Enable transfers; whitelist only sender
        vm.startPrank(governor);
        deployedSystem.fleet.setFleetTokenTransferability();
        deployedSystem.fleet.setWhitelisted(alice, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 300_000);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, bob));
        deployedSystem.fleet.transfer(bob, 120_000);
        vm.stopPrank();
    }

    function test_Transfer_Reverts_When_SenderNotWhitelisted() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(alice);

        // Enable transfers; whitelist only recipient
        vm.startPrank(governor);
        deployedSystem.fleet.setFleetTokenTransferability();
        deployedSystem.fleet.setWhitelisted(bob, true);
        deployedSystem.fleet.setWhitelisted(alice, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 100_000);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(alice, false);
        vm.stopPrank();

        // Alice is not whitelisted as sender
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, alice));
        deployedSystem.fleet.transfer(bob, 10_000);
        vm.stopPrank();
    }

    function test_TransferFrom_Reverts_When_Disabled_EvenIfFromAndToWhitelisted()
        public
    {
        address from = address(0xF00D);
        address to = address(0xB0B);
        address spender = address(0x5050);
        DeployedSytem memory deployedSystem = _deploy(from);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(from, true);
        deployedSystem.fleet.setWhitelisted(to, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 400_000);

        vm.prank(from);
        IERC20(address(deployedSystem.fleet)).approve(spender, 150_000);

        vm.prank(spender);
        vm.expectRevert(
            IFleetCommanderErrors.FleetCommanderTransfersDisabled.selector
        );
        deployedSystem.fleet.transferFrom(from, to, 150_000);
    }

    function test_TransferFrom_Reverts_When_Enabled_ToNotWhitelisted() public {
        address from = address(0xF00D);
        address to = address(0xB0B);
        address spender = address(0x5050);
        DeployedSytem memory deployedSystem = _deploy(from);

        vm.startPrank(governor);
        deployedSystem.fleet.setFleetTokenTransferability();
        deployedSystem.fleet.setWhitelisted(from, true);
        deployedSystem.fleet.setWhitelisted(spender, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 250_000);

        vm.prank(from);
        IERC20(address(deployedSystem.fleet)).approve(spender, 70_000);

        vm.startPrank(spender);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, to));
        deployedSystem.fleet.transferFrom(from, to, 70_000);
        vm.stopPrank();
    }
    function test_TransferFrom_Succeeds_When_Enabled_FromAndToWhitelisted()
        public
    {
        address from = address(0xF00D);
        address to = address(0xB0B);
        address spender = address(0x5050);
        DeployedSytem memory deployedSystem = _deploy(from);

        vm.startPrank(governor);
        deployedSystem.fleet.setFleetTokenTransferability();
        deployedSystem.fleet.setWhitelisted(from, true);
        deployedSystem.fleet.setWhitelisted(to, true);
        deployedSystem.fleet.setWhitelisted(spender, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 180_000);

        vm.prank(from);
        IERC20(address(deployedSystem.fleet)).approve(spender, 80_000);

        uint256 fromBefore = IERC20(address(deployedSystem.fleet)).balanceOf(
            from
        );
        vm.prank(spender);
        bool ok = deployedSystem.fleet.transferFrom(from, to, 80_000);
        assertTrue(
            ok,
            "transferFrom should succeed when enabled and both whitelisted"
        );
        assertEq(
            IERC20(address(deployedSystem.fleet)).balanceOf(from),
            fromBefore - 80_000,
            "from balance should decrease"
        );
        assertEq(IERC20(address(deployedSystem.fleet)).balanceOf(to), 80_000);
    }

    function test_TransferFrom_Reverts_When_Enabled_FromNotWhitelisted()
        public
    {
        address from = address(0xF00D);
        address to = address(0xB0B);
        address spender = address(0x5050);
        DeployedSytem memory deployedSystem = _deploy(from);

        vm.startPrank(governor);
        deployedSystem.fleet.setFleetTokenTransferability();
        deployedSystem.fleet.setWhitelisted(to, true);
        deployedSystem.fleet.setWhitelisted(from, true);
        deployedSystem.fleet.setWhitelisted(spender, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 120_000);

        vm.prank(from);
        IERC20(address(deployedSystem.fleet)).approve(spender, 40_000);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(from, false);
        vm.stopPrank();

        vm.startPrank(spender);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, from));
        deployedSystem.fleet.transferFrom(from, to, 40_000);
        vm.stopPrank();
    }

    // -----------------------------
    // Receiver gating (Fleet): deposit/mint/withdraw/redeem
    // -----------------------------
    function test_DepositDirect_Reverts_When_ReceiverNotWhitelisted() public {
        address user = address(0xBEEF);
        address receiver = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(user);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(user, true);
        // receiver intentionally not whitelisted
        vm.stopPrank();

        deal(deployedSystem.usdc, user, 10_000);
        vm.startPrank(user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.fleet),
            type(uint256).max
        );
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        deployedSystem.fleet.deposit(10_000, receiver);
        vm.stopPrank();
    }

    function test_MintDirect_Reverts_When_ReceiverNotWhitelisted() public {
        address user = address(0xBEEF);
        address receiver = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(user);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(user, true);
        vm.stopPrank();

        // preview assets and fund user
        deal(deployedSystem.usdc, user, 50_000);
        vm.startPrank(user);
        IERC20(deployedSystem.usdc).approve(
            address(deployedSystem.fleet),
            type(uint256).max
        );
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        deployedSystem.fleet.mint(10_000, receiver);
        vm.stopPrank();
    }

    function test_WithdrawDirect_Reverts_When_ReceiverNotWhitelisted() public {
        address user = address(0xBEEF);
        address receiver = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(user);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(user, true);
        // receiver intentionally not whitelisted
        vm.stopPrank();

        // deposit to get shares
        _depositDirectFleet(deployedSystem, 20_000);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        deployedSystem.fleet.withdraw(5_000, receiver, user);
        vm.stopPrank();
    }

    function test_RedeemDirect_Reverts_When_ReceiverNotWhitelisted() public {
        address user = address(0xBEEF);
        address receiver = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(user);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(user, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 30_000);
        uint256 shares = IERC20(address(deployedSystem.fleet)).balanceOf(user);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        deployedSystem.fleet.redeem(shares / 2, receiver, user);
        vm.stopPrank();
    }

    // -----------------------------
    // Owner gating (Fleet): withdraw/redeem
    // -----------------------------
    function test_WithdrawDirect_Reverts_When_OwnerNotWhitelisted() public {
        address user = address(0xBEEF);
        address receiver = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(user);

        vm.startPrank(governor);
        // whitelist caller and receiver, but NOT owner later
        deployedSystem.fleet.setWhitelisted(user, true);
        deployedSystem.fleet.setWhitelisted(receiver, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 25_000);

        // Remove owner whitelist
        vm.prank(governor);
        deployedSystem.fleet.setWhitelisted(user, false);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, user));
        deployedSystem.fleet.withdraw(5_000, receiver, user);
        vm.stopPrank();
    }

    function test_RedeemDirect_Reverts_When_OwnerNotWhitelisted() public {
        address user = address(0xBEEF);
        address receiver = address(0xB0B);
        DeployedSytem memory deployedSystem = _deploy(user);

        vm.startPrank(governor);
        deployedSystem.fleet.setWhitelisted(user, true);
        deployedSystem.fleet.setWhitelisted(receiver, true);
        vm.stopPrank();

        _depositDirectFleet(deployedSystem, 40_000);
        uint256 shares = IERC20(address(deployedSystem.fleet)).balanceOf(user);

        // Remove owner whitelist
        vm.prank(governor);
        deployedSystem.fleet.setWhitelisted(user, false);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, user));
        deployedSystem.fleet.redeem(shares / 2, receiver, user);
        vm.stopPrank();
    }
}
