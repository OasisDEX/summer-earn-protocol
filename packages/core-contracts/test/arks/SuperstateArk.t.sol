// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/SuperstateArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {AssetsForwarder} from "../../src/utils/AssetsForwarder/AssetsForwarder.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

// Dummy mock for Chainlink Oracle
contract MockSuperstateOracle is ISuperstateOracle {
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

contract MockSuperstateSubscribe is ISuperstateSubscribe {
    using SafeERC20 for IERC20;
    IERC20 public usdc;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    function subscribe(uint256 amount, address to) external {
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        // Minting happens later off-chain in tests
    }
}

contract MockSuperstateRedeem is ISuperstateRedeem {
    using SafeERC20 for IERC20;
    IERC20 public shareToken;

    constructor(address _shareToken) {
        shareToken = IERC20(_shareToken);
    }

    function redeem(uint256 amount, address to) external {
        shareToken.safeTransferFrom(msg.sender, address(this), amount);
        // USDC delivery happens later off-chain in tests
    }
}

contract SuperstateArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    event CustodianWalletUpdated(address oldWallet, address newWallet);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
    
    SuperstateArk public ark;
    BufferArk public bufferArk;
    IERC20 public usdc;
    MockERC20 public shareToken;
    MockSuperstateOracle public oracle;
    MockSuperstateSubscribe public subscribeContract;
    MockSuperstateRedeem public redeemContract;
    
    ArkParams public params;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 forkBlock = 21666256;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        keeper = makeAddr("keeper");

        shareToken = new MockERC20();
        shareToken.initialize("USTB", "USTB", 6);
        
        subscribeContract = new MockSuperstateSubscribe(USDC_ADDRESS);
        redeemContract = new MockSuperstateRedeem(address(shareToken));

        oracle = new MockSuperstateOracle(8, 10 * 1e8);

        params = ArkParams({
            name: "USDC Superstate Ark",
            details: "USDC Superstate Ark details",
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
        Percentage depositSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        ark = new SuperstateArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            sweepSlippage,
            depositSlippage,
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
        vm.expectRevert(SuperstateArk.InvalidShareTokenAddress.selector);
        new SuperstateArk(
            address(0),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        
        vm.expectRevert(SuperstateArk.InvalidSubscribeAddress.selector);
        new SuperstateArk(
            address(shareToken),
            address(0),
            address(redeemContract),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        vm.expectRevert(SuperstateArk.InvalidOracleAddress.selector);
        new SuperstateArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(0),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        assertEq(address(ark.asset()), USDC_ADDRESS, "Asset should match");
    }

    function test_Board_And_PendingDeposit() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialTargetBalance = usdc.balanceOf(address(subscribeContract));

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalTargetBalance = usdc.balanceOf(address(subscribeContract));
        assertEq(
            finalTargetBalance,
            initialTargetBalance + amount,
            "Target contract should receive tokens"
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
        uint256 amount = 10 * 1e6; // Exact price of 1 share
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // 2. Shares arrive off-chain
        uint256 sharesMinted = 1e6; // 1 USTB (6 decimals)
        shareToken.mint(address(ark), sharesMinted);

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
    
    function test_RequestWithdrawal_And_Sweep() public {
        // 1. Setup fully cleared deposit
        uint256 amount = 10 * 1e6; // 1 share worth
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e6; // 1 share
        shareToken.mint(address(ark), sharesMinted);

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
            shareToken.balanceOf(address(redeemContract)),
            sharesMinted,
            "Shares should be sent to redeem contract"
        );
        assertEq(
            shareToken.balanceOf(address(ark)),
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

        // The swept USDC goes to the Ark now from the redeem process
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
}
