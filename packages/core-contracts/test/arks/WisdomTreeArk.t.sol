// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/WisdomTreeArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {AssetsForwarder} from "../../src/utils/AssetsForwarder/AssetsForwarder.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

// Dummy mock for Chainlink Oracle
contract MockOracle is AggregatorV3Interface {
    uint8 public _decimals;
    int256 public _answer;

    uint80 public _roundId = 1;
    uint256 public _updatedAt;
    uint80 public _answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        _decimals = decimals_;
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _updatedAt = block.timestamp;
    }

    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundId = roundId;
        _answer = answer;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    )
        external
        pure
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert();
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }
}

contract WisdomTreeArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    event CustodianWalletUpdated(address oldWallet, address newWallet);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
    WisdomTreeArk public ark;
    BufferArk public bufferArk;
    IERC20 public usdc;
    MockERC20 public wtToken;
    MockOracle public oracle;
    ArkParams public params;

    address public constant USDC_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public targetWallet;

    uint256 forkBlock = 21666256;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        targetWallet = makeAddr("targetWallet");
        keeper = makeAddr("keeper");

        // Set up mock share token (18 decimals)
        wtToken = new MockERC20();
        wtToken.initialize("WTBTC", "WTBTC", 18);

        // Set up mock oracle (8 decimals, price = 1.00)
        // USDC has 6 decimals, WTBTC has 18 decimals, Oracle has 8 decimals
        // So a price of 1 means 1 WTBTC (1e18) = 1 USDC (1e6)
        // We will make 1 WTBTC = 60,000 USDC.
        // answer * 1e18 / 1e(8 + 18 - 6) = 60000 * 1e6
        // answer = 60000 * 1e8 = 6,000,000,000,000
        oracle = new MockOracle(8, 60000 * 1e8);

        params = ArkParams({
            name: "USDC WisdomTree Ark",
            details: "USDC WisdomTree Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        Percentage sweepSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        ark = new WisdomTreeArk(
            targetWallet,
            address(wtToken),
            address(oracle),
            sweepSlippage,
            WisdomTreeArk.WTArkType.NonMoneyMarket,
            params
        );
        vm.stopPrank();

        ArkParams memory bParams = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        bufferArk = new BufferArk(bParams, address(commander));

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);

        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        vm.expectRevert(WisdomTreeArk.InvalidTargetWallet.selector);
        new WisdomTreeArk(
            address(0),
            address(wtToken),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            WisdomTreeArk.WTArkType.NonMoneyMarket,
            params
        );

        vm.expectRevert(WisdomTreeArk.InvalidOracleAddress.selector);
        new WisdomTreeArk(
            targetWallet,
            address(wtToken),
            address(0),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            WisdomTreeArk.WTArkType.NonMoneyMarket,
            params
        );

        vm.expectRevert(WisdomTreeArk.InvalidShareTokenAddress.selector);
        new WisdomTreeArk(
            targetWallet,
            address(0),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            WisdomTreeArk.WTArkType.NonMoneyMarket,
            params
        );

        assertEq(
            ark.custodianWallet(),
            targetWallet,
            "Target wallet should match"
        );
        assertEq(address(ark.asset()), USDC_ADDRESS, "Asset should match");
    }

    function test_SetCustodianWallet() public {
        address newWallet = makeAddr("newWallet");

        // Reverts if called by non-keeper
        vm.prank(targetWallet);
        vm.expectRevert();
        ark.setCustodianWallet(newWallet);

        vm.startPrank(keeper);

        // Reverts if address(0)
        vm.expectRevert(WisdomTreeArk.InvalidTargetWallet.selector);
        ark.setCustodianWallet(address(0));

        // Success
        vm.expectEmit(false, false, false, true);
        emit CustodianWalletUpdated(targetWallet, newWallet);
        ark.setCustodianWallet(newWallet);

        vm.stopPrank();

        assertEq(
            ark.custodianWallet(),
            newWallet,
            "Custodian wallet should be updated"
        );
    }

    function test_Board_And_PendingDeposit() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialTargetBalance = usdc.balanceOf(targetWallet);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalTargetBalance = usdc.balanceOf(targetWallet);
        assertEq(
            finalTargetBalance,
            initialTargetBalance + amount,
            "Target wallet should receive tokens"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should match boarded amount (pending deposit)"
        );
        assertEq(
            ark.pendingDepositAssets(),
            amount,
            "Pending deposit should match"
        );
    }

    function test_ClearPendingDeposit() public {
        // 1. Board
        uint256 amount = 60000 * 1e6; // Exact price of 1 share
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // 2. Shares arrive off-chain
        uint256 sharesMinted = 1e18; // 1 WTBTC
        wtToken.mint(address(ark), sharesMinted);

        // 3. Keep clears
        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        assertEq(
            ark.pendingDepositAssets(),
            0,
            "Pending deposit should be cleared"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should perfectly transition to oracle share value"
        );
    }

    function test_SetArkFrozen() public {
        vm.prank(targetWallet);
        vm.expectRevert();
        ark.setArkFrozen(true, type(uint256).max);

        vm.startPrank(keeper);
        vm.expectEmit(false, false, false, true);
        emit ArkIsFrozenUpdated(true, 0);
        ark.setArkFrozen(true, type(uint256).max);
        vm.stopPrank();

        assertTrue(ark.isArkFrozen());
    }

    function test_RevertBoardWhenFrozen() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        vm.expectRevert(WisdomTreeArk.ArkIsFrozen.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_RevertRequestWithdrawalWhenFrozen() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        uint256 amount = 1000 * 1e6;
        vm.startPrank(keeper);
        vm.expectRevert(WisdomTreeArk.ArkIsFrozen.selector);
        ark.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function test_TotalAssetsIsCachedWhenFrozen_MaxUint256() public {
        uint256 amount = 60000 * 1e6; // 1 share worth
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e18;
        wtToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        uint256 assetsBeforeFreeze = ark.totalAssets();

        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        // Change oracle price
        oracle.setAnswer(120000 * 1e8);

        uint256 assetsAfterFreeze = ark.totalAssets();
        assertEq(
            assetsBeforeFreeze,
            assetsAfterFreeze,
            "Total assets should be cached if frozen"
        );

        vm.prank(keeper);
        ark.setArkFrozen(false, 0);

        uint256 assetsAfterUnfreeze = ark.totalAssets();
        assertTrue(
            assetsAfterUnfreeze > assetsBeforeFreeze,
            "Total assets should update after unfreeze"
        );
    }

    function test_TotalAssetsIsCachedWhenFrozen_NormalValue() public {
        uint256 amount = 60000 * 1e6; // 1 share worth
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e18;
        wtToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        uint256 customFrozenValue = 1337 * 1e6;

        vm.prank(keeper);
        ark.setArkFrozen(true, customFrozenValue);

        // Change oracle price
        oracle.setAnswer(120000 * 1e8);

        uint256 assetsAfterFreeze = ark.totalAssets();
        assertEq(
            assetsAfterFreeze,
            customFrozenValue,
            "Total assets should equal the custom frozen value"
        );

        vm.prank(keeper);
        ark.setArkFrozen(false, 0);

        uint256 assetsAfterUnfreeze = ark.totalAssets();
        assertTrue(
            assetsAfterUnfreeze > customFrozenValue,
            "Total assets should update after unfreeze"
        );
        assertTrue(
            assetsAfterUnfreeze > amount,
            "Total assets should reflect the new oracle price"
        );
    }

    function test_ClearPendingDepositAmount() public {
        uint256 amount = 60000 * 1e6; // Exact price of 1 share
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertEq(ark.pendingDepositAssets(), amount);

        uint256 clearAmount = 10000 * 1e6;

        vm.startPrank(keeper);
        ark.clearPendingDeposit(clearAmount);
        vm.stopPrank();

        assertEq(
            ark.pendingDepositAssets(),
            amount - clearAmount,
            "Pending deposit should be partially cleared"
        );
    }

    function test_RevertBoardWhenPendingDepositNonMoneyMarket() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount * 2);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount * 2);

        // First board succeeds
        ark.board(amount, bytes(""));

        // Second board reverts because it's a NonMoneyMarket ark
        vm.expectRevert(WisdomTreeArk.PendingDepositActive.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    /* Withdrawal Tests */

    function test_RequestWithdrawal_RevertsIfPendingDeposit() public {
        // 1. Board (creates pending deposit)
        uint256 amount = 60000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // 2. Try to withdraw
        vm.startPrank(keeper);
        vm.expectRevert(WisdomTreeArk.PendingDepositActive.selector);
        ark.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function test_RequestWithdrawal_And_Sweep() public {
        // 1. Setup fully cleared deposit
        uint256 amount = 60000 * 1e6; // 1 share worth
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e18;
        wtToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        // Verify initial state
        assertEq(ark.totalAssets(), amount);

        // 2. Request Withdrawal
        vm.startPrank(keeper);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // Verify post-request state
        assertEq(
            wtToken.balanceOf(targetWallet),
            sharesMinted,
            "Shares should be sent to target wallet"
        );
        assertEq(
            wtToken.balanceOf(address(ark)),
            0,
            "Ark should have 0 shares"
        );
        assertEq(
            ark.pendingWithdrawalShares(),
            sharesMinted,
            "Pending withdrawal tracks shares"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets remains stable during withdrawal"
        );

        // The swept USDC goes to the Ark now
        deal(USDC_ADDRESS, address(ark), amount);

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

        assertEq(
            ark.pendingWithdrawalShares(),
            0,
            "Pending withdrawal cleared"
        );
        assertEq(
            ark.totalAssets(),
            0,
            "Total assets drops to 0 after sweep sends USDC away"
        );
        assertEq(usdc.balanceOf(address(ark)), 0, "Ark has 0 USDC");
    }

    /* _withdrawableTotalAssets and Disembark should be no-ops for this Ark type */

    function test_Disembark_IsNoOp() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Sweep_Success() public {
        uint256 amount = 60000 * 1e6; // Equals 1 share worth exactly based on oracle Price
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e18;
        wtToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // 0.5% slippage expected to work. 60000e6 * 0.995 = 59700e6
        uint256 returnedUsdc = 59700 * 1e6;
        deal(USDC_ADDRESS, address(ark), returnedUsdc);

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

        assertEq(ark.pendingWithdrawalShares(), 0);
        assertEq(usdc.balanceOf(address(bufferArk)), returnedUsdc);
    }

    function test_Sweep_Reverts_InsufficientAssets() public {
        uint256 amount = 60000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e18;
        wtToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // 59600e6 is less than 59700e6 (0.5% slippage limit)
        uint256 returnedUsdc = 59600 * 1e6; // Fails slippage constraint
        deal(USDC_ADDRESS, address(ark), returnedUsdc);

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
        vm.expectRevert();
        ark.sweep();
        vm.stopPrank();
    }

    function test_EmergencySweep_Reverts_If_Not_Governor() public {
        vm.startPrank(keeper); // not governor
        vm.expectRevert();
        ark.emergencySweep();
        vm.stopPrank();
    }

    function test_EmergencySweep_Success() public {
        uint256 amount = 60000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e18;
        wtToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // Use returned Usdc far below the slippage limit
        uint256 returnedUsdc = 50000 * 1e6; // Fails slippage constraint
        deal(USDC_ADDRESS, address(ark), returnedUsdc);

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

        // Should work when called by governor
        vm.startPrank(governor);
        ark.emergencySweep();
        vm.stopPrank();

        assertEq(ark.pendingWithdrawalShares(), 0);
        assertEq(usdc.balanceOf(address(bufferArk)), returnedUsdc);
    }

    /* Oracle Validation Tests */

    function test_RevertIfOraclePriceNotPositive() public {
        oracle.setAnswer(0);
        vm.expectRevert(WisdomTreeArk.OraclePriceNotPositive.selector);
        ark.sharesToAssets(1e18);

        oracle.setAnswer(-1);
        vm.expectRevert(WisdomTreeArk.OraclePriceNotPositive.selector);
        ark.sharesToAssets(1e18);
    }

    function test_RevertIfOracleStale() public {
        // Heartbeat is 24 hours
        oracle.setRoundData(1, 60000 * 1e8, block.timestamp - 24 hours - 1, 1);
        vm.expectRevert(WisdomTreeArk.StaleOraclePrice.selector);
        ark.sharesToAssets(1e18);

        // updatedAt == 0 case
        oracle.setRoundData(1, 60000 * 1e8, 0, 1);
        vm.expectRevert(WisdomTreeArk.StaleOraclePrice.selector);
        ark.sharesToAssets(1e18);
    }
}
