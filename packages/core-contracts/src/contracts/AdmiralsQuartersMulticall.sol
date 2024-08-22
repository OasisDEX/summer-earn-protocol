// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

interface IFleetCommander {
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);
    function asset() external view returns (address);
}

contract AdmiralsQuartersMulticall is Ownable, Multicall {
    using SafeERC20 for IERC20;

    address public immutable oneInchRouter;

    // Custom errors
    error SwapFailed();
    error AssetMismatch();
    error InsufficientOutputAmount();
    error UnsupportedSwapFunction();

    constructor(address _oneInchRouter) Ownable(msg.sender) {
        oneInchRouter = _oneInchRouter;
    }

    function depositToFleet(
        address fleetCommander,
        IERC20 inputToken,
        uint256 amount,
        bytes calldata swapCalldata
    ) external returns (uint256) {
        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetToken = IERC20(fleet.asset());

        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 swappedAmount = _swap(
            inputToken,
            fleetToken,
            amount,
            swapCalldata
        );

        fleetToken.forceApprove(address(fleet), swappedAmount);
        return fleet.deposit(swappedAmount, msg.sender);
    }

    function withdrawFromFleet(
        address fleetCommander,
        uint256 amount,
        IERC20 outputToken,
        bytes calldata swapCalldata,
        uint256 minOutputAmount
    ) external returns (uint256) {
        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetToken = IERC20(fleet.asset());

        uint256 withdrawnAmount = fleet.withdraw(
            amount,
            address(this),
            msg.sender
        );
        uint256 swappedAmount = _swap(
            fleetToken,
            outputToken,
            withdrawnAmount,
            swapCalldata
        );

        if (swappedAmount < minOutputAmount) {
            revert InsufficientOutputAmount();
        }

        outputToken.safeTransfer(msg.sender, swappedAmount);
        return swappedAmount;
    }

    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        bytes calldata swapCalldata
    ) external returns (uint256) {
        fromToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 swappedAmount = _swap(fromToken, toToken, amount, swapCalldata);
        toToken.safeTransfer(msg.sender, swappedAmount);
        return swappedAmount;
    }

    function _swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        bytes calldata swapCalldata
    ) internal returns (uint256) {
        if (swapCalldata.length == 0) {
            if (address(fromToken) != address(toToken)) {
                revert AssetMismatch();
            }
            return amount;
        }

        fromToken.forceApprove(oneInchRouter, amount);
        (bool success, bytes memory returnData) = oneInchRouter.call(
            swapCalldata
        );
        if (!success) {
            revert SwapFailed();
        }
        return abi.decode(returnData, (uint256));
    }
}
