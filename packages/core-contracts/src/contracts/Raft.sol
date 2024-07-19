// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {SwapData} from "../types/RaftTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
IV3SwapRouter
} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

import "../errors/RaftErrors.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";

/**
 * @title Raft
 * @notice Manages the harvesting, swapping, and reinvesting of rewards for various Arks.
 * @dev This contract implements the IRaft interface and inherits access control from ArkAccessManaged.
 */
contract Raft is IRaft, ArkAccessManaged {
    IV3SwapRouter public immutable uniswapRouter;
    IUniswapV3Factory public immutable uniswapFactory;

    mapping(address => mapping(address => uint256)) public harvestedRewards;

    /**
     * @notice Constructs a new Raft contract.
     * @param _swapProvider_ The address of the swap provider (e.g., 1inch) used for token exchanges.
     * @param accessManager The address of the AccessManager contract for role-based permissions.
     */
    constructor(
        address _uniswapRouter_,
        address _uniswapFactory_,
        address accessManager
    ) ArkAccessManaged(accessManager) {
        require(uniswapV3RouterAddress != address(0), "raft/invalid-uniswap-v3-router-address");
        require(uniswapV3FactoryAddress != address(0), "raft/invalid-uniswap-v3-factory-address");

        uniswapRouter = IV3SwapRouter(uniswapV3RouterAddress);
        uniswapFactory = IUniswapV3Factory(uniswapV3FactoryAddress);
    }

    /**
     * @inheritdoc IRaft
     * @dev Only callable by addresses with the Keeper role.
     */
    function harvestAndReboard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external onlyKeeper {
        harvest(ark, rewardToken);
        _swap(ark, swapData);
        _reboard(ark, rewardToken);
    }

    /**
     * @inheritdoc IRaft
     * @dev Only callable by addresses with the Keeper role.
     */
    function swapAndReboard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external onlyKeeper {
        _swap(ark, swapData);
        _reboard(ark, rewardToken);
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
     * @inheritdoc IRaft
     */
    function getHarvestedRewards(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return harvestedRewards[ark][rewardToken];
    }

    /**
     * @dev Internal function to perform a swap operation using the swap provider.
     * @param ark The address of the Ark contract associated with the swap.
     * @param swapData Data required for the swap operation.
     */
    function _swap(address ark, SwapData memory swapData) internal {
        address tokenOut = address(IArk(ark).token());
        ERC20(swapData.tokenIn).safeApprove(address(uniswapRouter), swapData.amountIn);

        bytes memory path = abi.encodePacked(swapData.tokenIn, poolFee, tokenOut);

        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: swapData.amountIn,
            amountOutMinimum: swapData.amountOutMin
        });

        uint256 amountReceived = uniswapRouter.exactInput(params);
        if (amountReceived < swapData.amountOutMin) {
            revert ReceivedLess(swapData.amountOutMin, amountReceived);
        }

        emit RewardSwapped(
            swapData.tokenIn,
            tokenOut,
            swapData.amountIn,
            amountReceived
        );
    }

    /**
     * @dev Internal function to reinvest harvested rewards back into the Ark.
     * @param ark The address of the Ark contract to reinvest into.
     * @param rewardToken The address of the reward token being reinvested.
     */
    function _reboard(address ark, address rewardToken) internal {
        uint256 preSwapRewardBalance = harvestedRewards[ark][rewardToken];

        if (preSwapRewardBalance == 0) {
            revert NoRewardsToReinvest(ark, rewardToken);
        }

        uint256 balance = IArk(ark).token().balanceOf(address(this));
        IERC20(IArk(ark).token()).approve(ark, balance);
        IArk(ark).boardFromRaft(balance);

        harvestedRewards[ark][rewardToken] = 0;

        emit RewardReboarded(ark, rewardToken, preSwapRewardBalance, balance);
    }

    function getPrice(
        address ark,
        address tokenIn,
        uint24[] memory fees
    ) public view returns (uint256 price, uint24 fee) {
        address tokenOut = address(IArk(ark).token());

        uint24 biggestPoolFee;
        IUniswapV3Pool biggestPool;
        uint256 highestPoolBalance;
        uint256 currentPoolBalance;
        for (uint8 i; i < fees.length; i++) {
            IUniswapV3Pool pool = IUniswapV3Pool(
                uniswapFactory.getPool(tokenIn, tokenOut, fees[i])
            );
            if (address(pool) != address(0)) { // Ensure the pool exists
                currentPoolBalance = ERC20(tokenOut).balanceOf(address(pool));
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

    function _getTick(
        address uniswapV3Pool,
        uint32 twapInterval
    ) private view returns (uint160 sqrtPriceX96) {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            // past ---secondsAgo---> present
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
