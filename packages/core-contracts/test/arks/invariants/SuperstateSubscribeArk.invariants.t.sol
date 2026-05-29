// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {SuperstateSubscribeArk} from "../../../src/contracts/arks/SuperstateSubscribeArk.sol";
import {BufferArk} from "../../../src/contracts/arks/BufferArk.sol";
import {ArkParams} from "../../../src/types/ArkTypes.sol";

import {ArkTestBaseWhitelist} from "../ArkTestBaseWhitelist.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockShareTokenWithBurn, MockSuperstateSubscribeWithMint, MockRedeemContract, MockOracleWithDrift} from "./SuperstateInvariantsCommon.sol";
import {SuperstateSubscribeArkHandler} from "./SuperstateSubscribeArkHandler.sol";

/// @notice Invariant suite for SuperstateSubscribeArk. Subscribe has no async-deposit cycle and
///         no freeze, so the assertions are a subset of Standard's: slippage caps, the totalAssets
///         identity (unconditional), assetsInWithdrawalQueue identity, and the in-handler
///         post-conditions for sweep / requestWithdrawal / slippage setters.
contract SuperstateSubscribeArkInvariants is Test, ArkTestBaseWhitelist {
    SuperstateSubscribeArk public ark;
    SuperstateSubscribeArkHandler public handler;
    BufferArk public bufferArk;

    MockERC20 public usdc;
    MockShareTokenWithBurn public shareToken;
    MockSuperstateSubscribeWithMint public subscribeContract;
    MockRedeemContract public redeemContract;
    MockOracleWithDrift public oracle;

    function setUp() public {
        initializeCoreContracts();

        usdc = new MockERC20();
        usdc.initialize("USDC", "USDC", 6);

        shareToken = new MockShareTokenWithBurn();
        shareToken.initialize("USTB", "USTB", 6);

        oracle = new MockOracleWithDrift(8, 10 * 1e8);

        // Wire the share token's superstateOracle() to match what the Subscribe ark expects
        shareToken.setSuperstateOracle(address(oracle));
        shareToken.setSupportedStablecoin(address(usdc), address(0x5555));

        subscribeContract = new MockSuperstateSubscribeWithMint(
            address(usdc),
            address(oracle)
        );
        subscribeContract.setMintTarget(address(shareToken));

        redeemContract = new MockRedeemContract(
            address(shareToken),
            address(usdc)
        );

        ArkParams memory params = ArkParams({
            name: "Subscribe Ark",
            details: "details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        Percentage sweepSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        Percentage depositSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);

        ark = new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            sweepSlippage,
            depositSlippage,
            params
        );

        ArkParams memory bParams = ArkParams({
            name: "BufferArk",
            details: "buffer details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        bufferArk = new BufferArk(bParams, address(commander));

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), commander);
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();

        vm.mockCall(
            commander,
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            commander,
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        handler = new SuperstateSubscribeArkHandler(
            ark,
            shareToken,
            subscribeContract,
            redeemContract,
            oracle,
            address(usdc),
            keeper,
            governor,
            commander,
            address(bufferArk)
        );

        targetContract(address(handler));
    }

    /* ============================================================
                              INVARIANTS
    ============================================================ */

    function invariant_SweepSlippageBounded() public view {
        assertLe(
            Percentage.unwrap(ark.sweepSlippage()),
            Percentage.unwrap(ark.MAX_SWEEP_SLIPPAGE()),
            "I1: sweepSlippage > MAX_SWEEP_SLIPPAGE"
        );
    }

    function invariant_DepositSlippageBounded() public view {
        assertLe(
            Percentage.unwrap(ark.depositSlippage()),
            Percentage.unwrap(ark.MAX_DEPOSIT_SLIPPAGE()),
            "I2: depositSlippage > MAX_DEPOSIT_SLIPPAGE"
        );
    }

    /// @notice I3: Subscribe totalAssets is unconditionally
    ///         `_sharesToAssets(SHARE_TOKEN.balanceOf(this) + pendingWithdrawalShares)`.
    function invariant_TotalAssetsIdentity() public view {
        uint256 actual = ark.totalAssets();
        uint256 pending = ark.pendingWithdrawalShares();
        uint256 expected = ark.sharesToAssets(
            shareToken.balanceOf(address(ark)) + pending
        );
        assertEq(actual, expected, "I3: Subscribe totalAssets identity broken");
    }

    function invariant_AssetsInWithdrawalQueueIdentity() public view {
        uint256 pending = ark.pendingWithdrawalShares();
        assertEq(
            ark.assetsInWithdrawalQueue(),
            ark.sharesToAssets(pending),
            "I8: assetsInWithdrawalQueue identity broken"
        );
    }
}
