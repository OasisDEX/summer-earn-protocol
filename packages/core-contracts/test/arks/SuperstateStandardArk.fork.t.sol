// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SuperstateStandardArk.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {AggregatorV3Interface} from "../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateAllowlist {
    function owner() external view returns (address);
    function setProtocolAddressPermission(address addr, string calldata fund, bool isAllowed) external;
    function isAddressAllowedForFund(address addr, string calldata fund) external view returns (bool);
}

contract SuperstateStandardArkForkTest is Test, ArkTestBaseWhitelist {
    SuperstateStandardArk public ark;
    BufferArk public bufferArk;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Superstate USCC Mainnet addresses (https://docs.superstate.com/investors/smart-contracts)
    // USCC uses the same token proxy address for both subscriptions and redemptions
    address public constant USCC = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
    address public constant ALLOWLIST = 0x02f1fA8B196d21c7b733EB2700B825611d8A38E5;
    // Chainlink USCC / USD price feed (8 decimals)
    address public constant USCC_ORACLE = 0xAfFd8F5578E8590665de561bdE9E7BAdb99300d9;

    // Must be after USCC contract upgrade that supports current oracle
    uint256 public constant FORK_BLOCK = 25191026;

    ArkParams public arkParams;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        initializeCoreContracts();

        keeper = makeAddr("keeper");

        Percentage sweepSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        Percentage depositSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);

        arkParams = ArkParams({
            name: "USCC Superstate Standard Ark",
            details: "USCC Superstate Standard Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // USCC is the share token and deposit address; offchainRedeem handles withdrawals
        ark = new SuperstateStandardArk(
            USCC,
            USCC,
            USCC_ORACLE,
            sweepSlippage,
            depositSlippage,
            arkParams
        );

        // Impersonate the AllowList owner to whitelist the Ark for USCC transfers
        _whitelistForUSCC(address(ark));

        // Verify the whitelist was applied
        assertTrue(
            ISuperstateAllowlist(ALLOWLIST).isAddressAllowedForFund(address(ark), "USCC"),
            "Ark must be on USCC allowlist"
        );

        // Deploy a buffer ark so sweep() can board USDC into it
        ArkParams memory bufferParams = ArkParams({
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
        });
        bufferArk = new BufferArk(bufferParams, address(commander));

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

    /// @dev Impersonates the AllowList owner and grants protocol-level USCC permission to `addr`.
    function _whitelistForUSCC(address addr) internal {
        address allowlistAdmin = ISuperstateAllowlist(ALLOWLIST).owner();
        vm.startPrank(allowlistAdmin);
        ISuperstateAllowlist(ALLOWLIST).setProtocolAddressPermission(addr, "USCC", true);
        vm.stopPrank();
    }

    /**
     * @dev Returns the expected USCC shares for a given USDC amount using the
     *      live oracle.  Formula: shares = amount * 10^SHARE_DECIMALS / answer.
     *      All Superstate oracles and tokens use 6 decimals.
     */
    function _expectedUsccShares(uint256 usdcAmount) internal view returns (uint256) {
        (, int256 answer, , , ) = AggregatorV3Interface(USCC_ORACLE).latestRoundData();
        return (usdcAmount * 1e6) / uint256(answer);
    }

    // ─── Tests ──────────────────────────────────────────────────────────────────

    /**
     * @notice Verifies that board() transfers USDC to the USCC contract and records
     *         the pending deposit.  No real subscription happens — that is processed
     *         off-chain by Superstate (T+1/T+2).
     */
    function test_Fork_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC, commander, amount);

        uint256 usccContractUsdcBefore = IERC20(USDC).balanceOf(USCC);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // USDC must have been transferred to the USCC contract address
        assertEq(
            IERC20(USDC).balanceOf(USCC),
            usccContractUsdcBefore + amount,
            "USDC should have been sent to USCC contract"
        );

        // Ark records the amount as pending until Superstate mints USCC off-chain
        assertEq(ark.pendingDepositAssets(), amount, "pendingDepositAssets should equal boarded amount");
        assertEq(ark.totalAssets(), amount, "totalAssets counts pending deposit at face value");
    }

    /**
     * @notice Simulates off-chain USCC minting (via deal) and verifies that the keeper
     *         can clear the pending deposit once shares arrive.
     */
    function test_Fork_ClearPendingDeposit() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Simulate Superstate delivering USCC tokens off-chain (T+1)
        // deal() bypasses the USCC allowlist so no whitelist needed for this step
        uint256 usccShares = _expectedUsccShares(amount);
        deal(USCC, address(ark), usccShares);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        assertEq(ark.pendingDepositAssets(), 0, "pendingDepositAssets should be cleared");
        assertEq(
            ark.cachedShareBalance(),
            IERC20(USCC).balanceOf(address(ark)),
            "cachedShareBalance should match USCC balance"
        );
        // totalAssets() now derives from oracle price of held USCC shares
        assertGt(ark.totalAssets(), 0, "totalAssets should reflect oracle value of USCC shares");
        assertApproxEqRel(
            ark.totalAssets(),
            amount,
            0.01e18,
            "totalAssets should approximate the original USDC amount"
        );
    }

    /**
     * @notice Verifies that the keeper can initiate an async withdrawal via
     *         offchainRedeem(), which burns the Ark's USCC shares and triggers
     *         off-chain USDC settlement.  The Ark must be on the USCC allowlist.
     */
    function test_Fork_RequestWithdrawal() public {
        // Board + simulate share arrival + clear pending
        uint256 amount = 1000 * 1e6;
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 usccShares = _expectedUsccShares(amount);
        deal(USCC, address(ark), usccShares);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        uint256 totalAssetsValue = ark.totalAssets();

        // Keeper requests async withdrawal — offchainRedeem burns the Ark's shares
        vm.startPrank(keeper);
        ark.requestWithdrawal(totalAssetsValue);
        vm.stopPrank();

        // offchainRedeem burned the Ark's USCC shares
        // Allow 1 unit of dust due to oracle price rounding
        assertLe(IERC20(USCC).balanceOf(address(ark)), 1, "Ark should have at most 1 unit USCC dust");
        assertGt(ark.pendingWithdrawalShares(), 0, "pendingWithdrawalShares must be set");
    }

    /**
     * @notice Verifies the full lifecycle: board → clear pending → request withdrawal →
     *         sweep.  After Superstate returns USDC, the keeper sweeps it to the buffer ark.
     */
    function test_Fork_Sweep() public {
        // ── 1. Board ──────────────────────────────────────────────────────────
        uint256 amount = 1000 * 1e6;
        deal(USDC, commander, amount);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // ── 2. Simulate USCC minting + clear pending ──────────────────────────
        uint256 usccShares = _expectedUsccShares(amount);
        deal(USCC, address(ark), usccShares);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        // ── 3. Request withdrawal ─────────────────────────────────────────────
        uint256 totalAssetsValue = ark.totalAssets();

        vm.startPrank(keeper);
        ark.requestWithdrawal(totalAssetsValue);
        vm.stopPrank();

        assertGt(ark.pendingWithdrawalShares(), 0);

        // ── 4. Simulate Superstate returning USDC (T+1/T+2 settlement) ────────
        deal(USDC, address(ark), totalAssetsValue);

        // ── 5. Sweep USDC to buffer ark ───────────────────────────────────────
        // Mock the commander queries that sweep() relies on
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

        // ── 6. Verify final state ─────────────────────────────────────────────
        assertEq(ark.pendingWithdrawalShares(), 0, "pendingWithdrawalShares should be cleared after sweep");
        assertEq(IERC20(USDC).balanceOf(address(ark)), 0, "Ark should have 0 USDC after sweep");
        // USDC moved into the buffer ark
        assertGt(
            IERC20(USDC).balanceOf(address(bufferArk)),
            0,
            "Buffer ark should have received the swept USDC"
        );
    }
}
