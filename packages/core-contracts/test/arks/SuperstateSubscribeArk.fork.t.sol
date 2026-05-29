// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SuperstateSubscribeArk.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateAllowlist {
    function owner() external view returns (address);
    function setProtocolAddressPermission(
        address addr,
        string calldata fund,
        bool isAllowed
    ) external;
    function isAddressAllowedForFund(
        address addr,
        string calldata fund
    ) external view returns (bool);
}

contract SuperstateSubscribeArkForkTest is Test, ArkTestBaseWhitelist {
    SuperstateSubscribeArk public ark;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Superstate USTB Mainnet addresses (https://docs.superstate.com/investors/smart-contracts)
    address public constant USTB = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
    address public constant ALLOWLIST =
        0x02f1fA8B196d21c7b733EB2700B825611d8A38E5;
    address public constant USTB_REDEMPTION_IDLE =
        0x4c21B7577C8FE8b0B0669165ee7C8f67fa1454Cf;
    // Superstate USTB Continuous Price Oracle — must match USTB.superstateOracle()
    address public constant USTB_ORACLE =
        0xE4fA682f94610cCd170680cc3B045d77D9E528a8;

    // Must be after USTB upgrade that added subscribe(address,uint256,address)
    uint256 public constant FORK_BLOCK = 25191026;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        initializeCoreContracts();

        ArkParams memory params = ArkParams({
            name: "USTB Superstate Subscribe Ark",
            details: "USTB Superstate Subscribe Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // USTB token is both the share token and the subscribe target
        ark = new SuperstateSubscribeArk(
            USTB,
            USTB,
            USTB_REDEMPTION_IDLE,
            USTB_ORACLE,
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        // Impersonate the AllowList owner to whitelist the Ark for USTB transfers
        _whitelistForUSTB(address(ark));

        // Verify the whitelist was applied
        assertTrue(
            ISuperstateAllowlist(ALLOWLIST).isAddressAllowedForFund(
                address(ark),
                "USTB"
            ),
            "Ark must be on USTB allowlist"
        );

        // Setup access control
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    /// @dev Impersonates the AllowList owner and grants protocol-level USTB permission to `addr`.
    function _whitelistForUSTB(address addr) internal {
        address allowlistAdmin = ISuperstateAllowlist(ALLOWLIST).owner();
        vm.startPrank(allowlistAdmin);
        ISuperstateAllowlist(ALLOWLIST).setProtocolAddressPermission(
            addr,
            "USTB",
            true
        );
        vm.stopPrank();
    }

    /// @dev Boards USDC into the Ark (subscribe for USTB) and returns the USTB shares received.
    function _boardAndGetShares(
        uint256 amount
    ) internal returns (uint256 shares) {
        deal(USDC, commander, amount);
        uint256 ustbBefore = IERC20(USTB).balanceOf(address(ark));

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        shares = IERC20(USTB).balanceOf(address(ark)) - ustbBefore;
    }

    // ─── Tests ──────────────────────────────────────────────────────────────────

    /**
     * @notice Verifies that boarding with real USDC calls USTB.subscribe(),
     *         mints USTB to the Ark, and that totalAssets() correctly reflects the
     *         oracle-denominated value of the received shares.
     */
    function test_Fork_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC

        uint256 shares = _boardAndGetShares(amount);

        // USTB tokens must have been minted to the Ark via subscribe()
        assertGt(shares, 0, "Ark should have received USTB after subscribe");

        // Oracle-based totalAssets() should closely match the deposited USDC (within 1%)
        assertApproxEqRel(
            ark.totalAssets(),
            amount,
            0.01e18,
            "totalAssets should approximate the deposited USDC"
        );
    }

    /**
     * @notice Verifies the async (off-chain) withdrawal path: the keeper calls
     *         requestWithdrawal(), which burns USTB shares via offchainRedeem and updates
     *         pendingWithdrawalShares.
     */
    function test_Fork_RequestWithdrawal() public {
        uint256 amount = 1000 * 1e6;
        _boardAndGetShares(amount);

        uint256 totalAssetsValue = ark.totalAssets();
        uint256 ustbInArk = IERC20(USTB).balanceOf(address(ark));
        uint256 ustbSupplyBefore = IERC20(USTB).totalSupply();

        assertGt(ustbInArk, 0, "Ark must have USTB before withdrawal");
        assertGt(totalAssetsValue, 0, "totalAssets must be > 0");

        // Keeper initiates the async off-chain redemption path
        vm.startPrank(keeper);
        ark.requestWithdrawal(totalAssetsValue);
        vm.stopPrank();

        // USTB shares should have been burned (offchainRedeem reduces total supply)
        uint256 ustbSupplyAfter = IERC20(USTB).totalSupply();
        assertLt(
            ustbSupplyAfter,
            ustbSupplyBefore,
            "USTB total supply should have dropped (shares burned by offchainRedeem)"
        );

        // pendingWithdrawalShares tracks the burned shares awaiting off-chain settlement
        assertGt(
            ark.pendingWithdrawalShares(),
            0,
            "pendingWithdrawalShares must be set"
        );

        // Ark's direct USTB balance should have decreased
        assertLt(
            IERC20(USTB).balanceOf(address(ark)),
            ustbInArk,
            "Ark USTB balance should have decreased"
        );
    }

    /**
     * @notice Verifies that disembark reverts when the RedemptionIdle contract
     *         cannot process synchronous redemption.
     *
     *         The RedemptionIdle.redeem() has internal requirements (e.g. NAV
     *         oracle checks, market-hours gating) that cannot easily be satisfied
     *         in a fork test. When sync redemption is unavailable, `_disembark`
     *         reverts with `DirectWithdrawalNotAvailable`; the keeper is expected
     *         to detect this and route through `requestWithdrawal` (async path).
     *
     *         The correct async withdrawal flow is tested by test_Fork_RequestWithdrawal
     *         and test_Fork_Sweep.
     */
    function test_Fork_Disembark_RevertsWhenSyncUnavailable() public {
        uint256 amount = 1000 * 1e6;
        _boardAndGetShares(amount);

        uint256 totalAssetsValue = ark.totalAssets();

        vm.prank(commander);
        vm.expectRevert();
        ark.disembark(totalAssetsValue, bytes(""));
    }

    /**
     * @notice Verifies the full lifecycle: board → request withdrawal → sweep.
     *         After the keeper requests async withdrawal and Superstate returns
     *         USDC (simulated via deal), the keeper sweeps it to the buffer ark.
     */
    function test_Fork_Sweep() public {
        // ── 1. Board ──────────────────────────────────────────────────────────
        uint256 amount = 1000 * 1e6;
        _boardAndGetShares(amount);

        uint256 totalAssetsValue = ark.totalAssets();
        assertGt(totalAssetsValue, 0, "totalAssets must be > 0 after board");

        // ── 2. Request async withdrawal ───────────────────────────────────────
        vm.startPrank(keeper);
        ark.requestWithdrawal(totalAssetsValue);
        vm.stopPrank();

        assertGt(
            ark.pendingWithdrawalShares(),
            0,
            "pendingWithdrawalShares should be set"
        );
        // Allow 1 unit of USTB dust due to oracle price rounding
        assertLe(
            IERC20(USTB).balanceOf(address(ark)),
            1,
            "Ark should have at most 1 unit USTB dust"
        );

        // ── 3. Simulate Superstate returning USDC (T+1 settlement) ────────────
        deal(USDC, address(ark), totalAssetsValue);

        // ── 4. Sweep — base ArkWithWithdrawalRequest.sweep() sends USDC to buffer ark
        // Mock the commander queries that sweep() relies on (bufferArk, isArkActiveOrBufferArk)
        BufferArk bufferArk = new BufferArk(
            ArkParams({
                name: "Buffer Ark",
                details: "Buffer Ark details",
                accessManager: address(accessManager),
                configurationManager: address(configurationManager),
                asset: USDC,
                depositCap: type(uint256).max,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false,
                maxDepositPercentageOfTVL: PERCENTAGE_100
            }),
            address(commander)
        );

        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        vm.startPrank(keeper);
        ark.sweep();
        vm.stopPrank();

        // ── 5. Verify final state ─────────────────────────────────────────────
        assertEq(
            IERC20(USDC).balanceOf(address(ark)),
            0,
            "Ark should have 0 USDC after sweep"
        );
        assertGt(
            IERC20(USDC).balanceOf(address(bufferArk)),
            0,
            "Buffer ark should have received the swept USDC"
        );
    }
}
