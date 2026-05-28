// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SuperstateSubscribeArk.sol";
import {AggregatorV3Interface} from "../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {ISuperstateToken, SupportedStablecoin} from "../../src/interfaces/superstate/ISuperstateToken.sol";
import {ISuperstateRedeem} from "../../src/interfaces/superstate/ISuperstateRedeem.sol";
import "../../src/events/IArkEvents.sol";
import {ISuperstateArkErrors} from "../../src/errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateSubscribeArkErrors} from "../../src/errors/arks/ISuperstateSubscribeArkErrors.sol";
import {ISuperstateSubscribeArk} from "../../src/interfaces/arks/ISuperstateSubscribeArk.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

// Dummy mock for Chainlink Oracle
contract MockSuperstateOracle is AggregatorV3Interface {
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

    function description() external view override returns (string memory) {
        return "MockOracle";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80 _roundId
    )
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

contract MockSuperstateSubscribe is ISuperstateToken {
    using SafeERC20 for IERC20;
    IERC20 public usdc;
    address public _superstateOracle;

    constructor(address _usdc, address oracle_) {
        usdc = IERC20(_usdc);
        _superstateOracle = oracle_;
    }

    function subscribe(
        address /*to*/,
        uint256 inAmount,
        address stablecoin
    ) external override {
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            inAmount
        );
    }

    function subscribe(uint256 inAmount, address stablecoin) external override {
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            inAmount
        );
    }

    function supportedStablecoins(
        address /*stablecoin*/
    ) external pure override returns (SupportedStablecoin memory) {
        return SupportedStablecoin({sweepDestination: address(0x5555), fee: 0});
    }

    function superstateOracle() external view override returns (address) {
        return _superstateOracle;
    }

    function offchainRedeem(uint256) external override {}
}

contract MockSuperstateRedeem is ISuperstateRedeem {
    using SafeERC20 for IERC20;
    IERC20 public shareToken;
    IERC20 public usdc;

    constructor(address _shareToken, address _usdc) {
        shareToken = IERC20(_shareToken);
        usdc = IERC20(_usdc);
    }

    function redeem(uint256 amount, address to) external {
        shareToken.safeTransferFrom(msg.sender, address(this), amount);
        usdc.safeTransfer(to, amount * 10);
    }

    function withdraw(address /*_token*/, address to, uint256 amount) external {
        shareToken.safeTransferFrom(msg.sender, address(this), amount);
        usdc.safeTransfer(to, amount * 10);
    }
}

contract MockSuperstateToken is MockERC20, ISuperstateToken {
    address public expectedStablecoin;
    address public configuredSweepDestination;

    function setSupportedStablecoin(
        address stablecoin,
        address sweepDestination
    ) external {
        expectedStablecoin = stablecoin;
        configuredSweepDestination = sweepDestination;
    }

    function supportedStablecoins(
        address stablecoin
    ) external view override returns (SupportedStablecoin memory) {
        if (stablecoin == expectedStablecoin) {
            return
                SupportedStablecoin({
                    sweepDestination: configuredSweepDestination,
                    fee: 0
                });
        }
        return SupportedStablecoin({sweepDestination: address(0), fee: 0});
    }

    function subscribe(address, uint256, address) external override {}

    function subscribe(uint256, address) external override {}

    function superstateOracle() external pure override returns (address) {
        return address(0);
    }

    function offchainRedeem(uint256) external override {}
}

contract SuperstateSubscribeArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    SuperstateSubscribeArk public ark;
    IERC20 public usdc;
    MockSuperstateToken public shareToken;
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

        shareToken = new MockSuperstateToken();
        shareToken.initialize("USTB", "USTB", 6);
        shareToken.setSupportedStablecoin(USDC_ADDRESS, address(0x5555));

        subscribeContract = new MockSuperstateSubscribe(USDC_ADDRESS, address(oracle));
        redeemContract = new MockSuperstateRedeem(
            address(shareToken),
            USDC_ADDRESS
        );

        oracle = new MockSuperstateOracle(8, 10 * 1e8); // 1 share = 10 USDC

        params = ArkParams({
            name: "USDC Superstate Subscribe Ark",
            details: "USDC Superstate Subscribe Ark details",
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
        ark = new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            params
        );
        vm.stopPrank();

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
        vm.expectRevert(ISuperstateArkErrors.InvalidShareTokenAddress.selector);
        new SuperstateSubscribeArk(
            address(0),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            params
        );

        vm.expectRevert(
            ISuperstateSubscribeArkErrors.InvalidSubscribeAddress.selector
        );
        new SuperstateSubscribeArk(
            address(shareToken),
            address(0),
            address(redeemContract),
            address(oracle),
            params
        );

        vm.expectRevert(ISuperstateArkErrors.InvalidOracleAddress.selector);
        new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(0),
            params
        );

        assertEq(address(ark.asset()), USDC_ADDRESS, "Asset should match");
    }

    function test_UnsupportedStablecoin() public {
        vm.startPrank(governor);

        vm.mockCall(
            address(subscribeContract),
            abi.encodeWithSelector(
                ISuperstateToken.supportedStablecoins.selector,
                USDC_ADDRESS
            ),
            abi.encode(address(0), uint96(0))
        );

        vm.expectRevert(
            ISuperstateSubscribeArkErrors.UnsupportedStablecoin.selector
        );
        new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            params
        );
        vm.stopPrank();
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialTargetBalance = usdc.balanceOf(
            address(subscribeContract)
        );

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalTargetBalance = usdc.balanceOf(address(subscribeContract));
        assertEq(
            finalTargetBalance,
            initialTargetBalance + amount,
            "Subscribe contract should receive tokens"
        );

        // After boarding, shares are theoretically minted by Superstate.
        // We will simulate that:
        shareToken.mint(address(ark), 100 * 1e6); // 100 shares * 10 = 1000 USDC

        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should match boarded amount"
        );
    }

    function test_Disembark() public {
        // Setup initial shares
        uint256 amount = 1000 * 1e6;
        uint256 shares = 100 * 1e6;
        shareToken.mint(address(ark), shares);

        // Need to give the redeem contract USDC to pay out
        deal(USDC_ADDRESS, address(redeemContract), amount);

        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();

        assertEq(
            shareToken.balanceOf(address(redeemContract)),
            shares,
            "Redeem contract should receive shares"
        );
    }
}
