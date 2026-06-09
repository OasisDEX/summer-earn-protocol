// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AggregatorV3Interface} from "../../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {ISuperstateToken, SupportedStablecoin} from "../../../src/interfaces/superstate/ISuperstateToken.sol";
import {ISuperstateRedeem} from "../../../src/interfaces/superstate/ISuperstateRedeem.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

/// @notice Shared mocks for the Superstate ark invariant tests. The key difference from the unit
///         test mocks is that `offchainRedeem` actually burns the caller's balance and `subscribe`
///         deterministically mints into a configured share token, so share-conservation reasoning
///         in invariant tests holds.

contract MockShareTokenWithBurn is MockERC20, ISuperstateToken {
    address public _superstateOracle;
    address public expectedStablecoin;
    address public configuredSweepDestination = address(0x5555);

    /// @notice Per-recipient cumulative mint counter. Used by the share conservation invariant
    ///         (`totalMintedTo[ark] == balanceOf(ark) + totalBurnedFrom[ark] + sharesTransferredOut`).
    mapping(address => uint256) public totalMintedTo;
    /// @notice Per-caller cumulative burn counter (via `offchainRedeem`).
    mapping(address => uint256) public totalBurnedFrom;

    function setSuperstateOracle(address o) external {
        _superstateOracle = o;
    }

    function setSupportedStablecoin(
        address stablecoin,
        address sweepDestination
    ) external {
        expectedStablecoin = stablecoin;
        configuredSweepDestination = sweepDestination;
    }

    function supportedStablecoins(
        address /*stablecoin*/
    ) external view override returns (SupportedStablecoin memory) {
        return
            SupportedStablecoin({
                sweepDestination: configuredSweepDestination,
                fee: 0
            });
    }

    function superstateOracle() external view override returns (address) {
        return _superstateOracle;
    }

    function subscribe(address, uint256, address) external override {
        // Subscribe is exercised through MockSuperstateSubscribeWithMint, not directly here.
    }

    function subscribe(uint256, address) external override {
        // Same as above — only the Subscribe ark calls subscribe.
    }

    function offchainRedeem(uint256 amount) external override {
        totalBurnedFrom[msg.sender] += amount;
        _burn(msg.sender, amount);
    }

    function _mint(address to, uint256 amount) internal override {
        super._mint(to, amount);
        totalMintedTo[to] += amount;
    }
}

contract MockSuperstateSubscribeWithMint is ISuperstateToken {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    address public _superstateOracle;
    MockShareTokenWithBurn public mintTarget;
    uint256 public mintNum = 1;
    uint256 public mintDen = 10;

    constructor(address _usdc, address oracle_) {
        usdc = IERC20(_usdc);
        _superstateOracle = oracle_;
    }

    function setMintTarget(address shareToken_) external {
        mintTarget = MockShareTokenWithBurn(shareToken_);
    }

    function setMintRatio(uint256 num, uint256 den) external {
        mintNum = num;
        mintDen = den;
    }

    function subscribe(
        address to,
        uint256 inAmount,
        address stablecoin
    ) external override {
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            inAmount
        );
        if (address(mintTarget) != address(0) && mintDen > 0) {
            mintTarget.mint(to, (inAmount * mintNum) / mintDen);
        }
    }

    function subscribe(uint256 inAmount, address stablecoin) external override {
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            inAmount
        );
        if (address(mintTarget) != address(0) && mintDen > 0) {
            mintTarget.mint(msg.sender, (inAmount * mintNum) / mintDen);
        }
    }

    function supportedStablecoins(
        address /*stablecoin*/
    ) external pure override returns (SupportedStablecoin memory) {
        return SupportedStablecoin({sweepDestination: address(0x5555), fee: 0});
    }

    function superstateOracle() external view override returns (address) {
        return _superstateOracle;
    }

    function offchainRedeem(uint256) external override {
        // Subscribe ark uses offchainRedeem via the share token itself, not via the subscribe contract.
    }
}

contract MockRedeemContract is ISuperstateRedeem {
    using SafeERC20 for IERC20;

    IERC20 public immutable shareToken;
    IERC20 public immutable usdc;
    /// @notice USDC paid per share-wei during sync redeem. Default matches the 10:1 oracle mock.
    uint256 public usdcPerShare = 10;
    /// @notice Cumulative shares received via `redeem`. Used by the Subscribe-ark share conservation
    ///         invariant (these shares left the ark via `safeTransferFrom`).
    uint256 public totalSharesReceived;

    constructor(address _shareToken, address _usdc) {
        shareToken = IERC20(_shareToken);
        usdc = IERC20(_usdc);
    }

    function setUsdcPerShare(uint256 rate) external {
        usdcPerShare = rate;
    }

    function redeem(uint256 amount, address to) external override {
        totalSharesReceived += amount;
        shareToken.safeTransferFrom(msg.sender, address(this), amount);
        usdc.safeTransfer(to, amount * usdcPerShare);
    }
}

contract MockOracleWithDrift is AggregatorV3Interface {
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
        uint80 roundId_,
        int256 answer_,
        uint256 updatedAt_,
        uint80 answeredInRound_
    ) external {
        _roundId = roundId_;
        _answer = answer_;
        _updatedAt = updatedAt_;
        _answeredInRound = answeredInRound_;
    }

    function touch() external {
        _updatedAt = block.timestamp;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }

    function description() external pure override returns (string memory) {
        return "MockOracleWithDrift";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    )
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }
}
