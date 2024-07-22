// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {SwapData} from "../types/RaftTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../errors/RaftErrors.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

/**
 * @title Raft
 * @notice This contract manages the harvesting, swapping, and boarding of rewards for Arks.
 * @dev Implements the IRaft interface and inherits from ArkAccessManaged for access control.
 */
contract Raft is IRaft, ArkAccessManaged {
    using SafeERC20 for IERC20;

    ISwapRouter public immutable uniswapRouter;
    IUniswapV3Factory public immutable uniswapFactory;
    uint24[] public allowedFeeTiers = [100, 500, 3000, 10000];
    address public immutable WETH;

    mapping(address => mapping(address => uint256)) public harvestedRewards;

    /**
     * @notice Constructor to initialize the Raft contract
     * @param _uniswapRouter_ Address of the Uniswap V3 router
     * @param _uniswapFactory_ Address of the Uniswap V3 factory
     * @param _WETH_ Address of the WETH token
     * @param accessManager Address of the access manager contract
     */
    constructor(
        address _uniswapRouter_,
        address _uniswapFactory_,
        address _WETH_,
        address accessManager
    ) ArkAccessManaged(accessManager) {
        require(_uniswapRouter_ != address(0), "raft/invalid-uniswap-v3-router-address");
        require(_uniswapFactory_ != address(0), "raft/invalid-uniswap-v3-factory-address");
        require(_WETH_ != address(0), "raft/invalid-weth-address");

        uniswapRouter = ISwapRouter(_uniswapRouter_);
        uniswapFactory = IUniswapV3Factory(_uniswapFactory_);
        WETH = _WETH_;
    }

    /**
     * @inheritdoc IRaft
     */
    function harvestAndBoard(
        address ark,
        address rewardToken
    ) external onlyKeeper {
        harvest(ark, rewardToken);
        _swap(ark, rewardToken);
        _board(ark, rewardToken);
    }

    /**
     * @inheritdoc IRaft
     */
    function swapAndBoard(
        address ark,
        address rewardToken
    ) external onlyKeeper {
        _swap(ark, rewardToken);
        _board(ark, rewardToken);
    }

    /**
     * @inheritdoc IRaft
     */
    function harvest(address ark, address rewardToken) public {
        uint256 harvestedAmount = IArk(ark).harvest(rewardToken);
        harvestedRewards[ark][rewardToken] += harvestedAmount;
        emit ArkHarvested(ark, rewardToken);
    }

    /**
     * @dev Internal function to perform a swap operation.
     * @param ark The address of the Ark contract.
     * @param tokenIn The address of the reward token
     */
    function _swap(address ark, address tokenIn) internal {
        address tokenOut = address(IArk(ark).token());
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        bytes memory path;
        uint256 amountOutMin;

        // Determine if we need an intermediate hop through WETH
        if (tokenOut == WETH) {
            // Single hop: tokenIn -> WETH
            (uint256 price, uint24 fee) = getPrice(tokenIn, WETH, allowedFeeTiers);
            path = abi.encodePacked(tokenIn, fee, WETH);
            amountOutMin = amountIn * price / (10 ** ERC20(tokenIn).decimals());
        } else {
            // Multi-hop: tokenIn -> WETH -> tokenOut
            (uint256 price1, uint24 fee1) = getPrice(tokenIn, WETH, allowedFeeTiers);
            (uint256 price2, uint24 fee2) = getPrice(WETH, tokenOut, allowedFeeTiers);
            path = abi.encodePacked(tokenIn, fee1, WETH, fee2, tokenOut);

            uint256 intermediateAmount = amountIn * price1 / (10 ** ERC20(tokenIn).decimals());
            amountOutMin = intermediateAmount * price2 / (10 ** ERC20(WETH).decimals());
        }

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            deadline: block.timestamp + 300 // 300 seconds (5 minutes) as a buffer time
        });

        uint256 amountReceived = uniswapRouter.exactInput(params);
        if (amountReceived < amountOutMin) {
            revert ReceivedLess(amountOutMin, amountReceived);
        }

        emit RewardSwapped(
            tokenIn,
            tokenOut,
            amountIn,
            amountReceived
        );
    }

    /**
     * @dev Internal function to reinvest harvested rewards.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token to be reinvested.
     */
    function _board(address ark, address rewardToken) internal {
        uint256 preSwapRewardBalance = harvestedRewards[ark][rewardToken];

        if (preSwapRewardBalance == 0) {
            revert NoRewardsToReinvest(ark, rewardToken);
        }

        uint256 balance = IArk(ark).token().balanceOf(address(this));
        IERC20(IArk(ark).token()).approve(ark, balance);
        IArk(ark).boardFromRaft(balance);

        harvestedRewards[ark][rewardToken] = 0;

        emit RewardBoarded(ark, rewardToken, preSwapRewardBalance, balance);
    }

    /**
     * @inheritdoc IRaft
     */
    function getHarvestedRewards(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return harvestedRewards[ark][rewardToken];
    }

    /**
     * @notice Sets the allowed fee tiers for Uniswap V3 pools
     * @param _allowedFeeTiers_ An array of allowed fee tiers
     */
    function setAllowedFeeTiers(uint24[] memory _allowedFeeTiers_) public onlyGovernor {
        allowedFeeTiers = _allowedFeeTiers_;
    }

    /**
     * @notice Gets the price and fee for a token pair
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param fees An array of fee tiers to check
     * @return price The price of tokenOut in terms of tokenIn
     * @return fee The fee tier of the selected pool
     */
    function getPrice(
        address tokenIn,
        address tokenOut,
        uint24[] memory fees
    ) public view returns (uint256 price, uint24 fee) {
        uint24 biggestPoolFee;
        IUniswapV3Pool biggestPool;
        uint256 highestPoolBalance;
        uint256 currentPoolBalance;
        for (uint8 i; i < fees.length; i++) {
            IUniswapV3Pool pool = IUniswapV3Pool(
                uniswapFactory.getPool(tokenIn, tokenOut, fees[i])
            );
            if (address(pool) != address(0)) { // Ensure the pool exists
                currentPoolBalance = IERC20(tokenOut).balanceOf(address(pool));
                if (currentPoolBalance > highestPoolBalance) {
                    biggestPoolFee = fees[i];
                    biggestPool = pool;
                    highestPoolBalance = currentPoolBalance;
                }
            }
        }

        if (address(biggestPool) == address(0)) {
            revert NoSuitablePoolFound();
        }

        uint160 sqrtPriceX96 = _getTick(address(biggestPool), 60);
        address token0 = biggestPool.token0();
        uint256 decimalsIn = ERC20(tokenIn).decimals();
        uint256 decimalsOut = ERC20(tokenOut).decimals();

        if (token0 == tokenIn) {
            return (
                (uint256(sqrtPriceX96) * (uint256(sqrtPriceX96)) * (10 ** decimalsIn)) / (10 ** decimalsOut) / 2 ** 192,
                biggestPoolFee
            );
        } else {
            return (
                ((2 ** 192) * (10 ** decimalsOut) * (10 ** decimalsIn)) / (uint256(sqrtPriceX96) * (uint256(sqrtPriceX96))),
                biggestPoolFee
            );
        }
    }

    /**
     * @dev Internal function to get the sqrt price of a Uniswap V3 pool
     * @param uniswapV3Pool The address of the Uniswap V3 pool
     * @param twapInterval The time-weighted average price (TWAP) interval
     * @return sqrtPriceX96 The sqrt price of the pool
     */
    function _getTick(
        address uniswapV3Pool,
        uint32 twapInterval
    ) private view returns (uint160 sqrtPriceX96) {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = 1 + twapInterval; // secondsAgo
            secondsAgos[1] = 1; // now

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos);

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
            );
        }
        return sqrtPriceX96;
    }
}