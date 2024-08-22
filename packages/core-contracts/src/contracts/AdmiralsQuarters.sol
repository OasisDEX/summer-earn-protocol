// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

/// @title AdmiralsQuarters
/// @notice A contract for managing multiple FleetCommander instances and performing swaps using 1inch
/// @dev This contract allows users to enter, exit, and move between different fleets, optionally performing swaps
contract AdmiralsQuarters is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The address of the 1inch router contract
    address public immutable oneInchRouter;

    // 1inch function selectors
    bytes4 private constant SWAP_SELECTOR = 0x07ed2379;
    bytes4 private constant UNOSWAP_SELECTOR = 0x83800a8e;
    bytes4 private constant UNISWAP_V3_SWAP_SELECTOR = 0xe449022e;

    // Custom errors
    error MismatchedInputLengths();
    error NoFleetsProvided();
    error SwapFailed();
    error AssetMismatch();
    error InsufficientOutputAmount();
    error UnsupportedSwapFunction();

    constructor(address _oneInchRouter) Ownable(msg.sender) {
        oneInchRouter = _oneInchRouter;
    }

    function enterFleets(
        address[] calldata fleetCommanders,
        uint256[] calldata allocations,
        IERC20 inputToken,
        uint256 inputAmount,
        bytes[] calldata swapCalldatas
    ) external {
        if (
            fleetCommanders.length != allocations.length ||
            fleetCommanders.length != swapCalldatas.length
        ) {
            revert MismatchedInputLengths();
        }
        if (fleetCommanders.length == 0) {
            revert NoFleetsProvided();
        }

        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            totalAllocation += allocations[i];
        }

        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);

        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            uint256 fleetAllocation = (inputAmount * allocations[i]) /
                totalAllocation;
            IFleetCommander fleet = IFleetCommander(fleetCommanders[i]);
            IERC20 fleetToken = IERC20(fleet.asset());

            uint256 swappedAmount = _swap(
                inputToken,
                fleetToken,
                fleetAllocation,
                swapCalldatas[i]
            );
            _depositToFleet(fleet, fleetToken, swappedAmount, msg.sender);
        }
    }

    function exitFleets(
        address[] calldata fleetCommanders,
        uint256[] calldata tokenAmounts,
        IERC20 outputToken,
        uint256 minOutputAmount,
        bytes[] calldata swapCalldatas
    ) external {
        if (
            fleetCommanders.length != tokenAmounts.length ||
            fleetCommanders.length != swapCalldatas.length
        ) {
            revert MismatchedInputLengths();
        }
        if (fleetCommanders.length == 0) {
            revert NoFleetsProvided();
        }

        uint256 totalOutputAmount = 0;

        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            IFleetCommander fleet = IFleetCommander(fleetCommanders[i]);
            IERC20 fleetToken = IERC20(fleet.asset());

            uint256 withdrawnAmount = _withdrawFromFleet(
                fleet,
                tokenAmounts[i],
                msg.sender
            );
            uint256 swappedAmount = _swap(
                fleetToken,
                outputToken,
                withdrawnAmount,
                swapCalldatas[i]
            );
            totalOutputAmount += swappedAmount;
        }

        if (totalOutputAmount < minOutputAmount) {
            revert InsufficientOutputAmount();
        }
        outputToken.safeTransfer(msg.sender, totalOutputAmount);
    }

    function moveFleets(
        address fromFleet,
        address toFleet,
        uint256 shareAmount,
        uint256 minOutputAmount,
        bytes calldata swapCalldata
    ) external {
        IFleetCommander fromFleetCommander = IFleetCommander(fromFleet);
        IFleetCommander toFleetCommander = IFleetCommander(toFleet);
        IERC20 fromToken = IERC20(fromFleetCommander.asset());
        IERC20 toToken = IERC20(toFleetCommander.asset());

        uint256 withdrawnAmount = _withdrawFromFleet(
            fromFleetCommander,
            shareAmount,
            msg.sender
        );
        uint256 swappedAmount = _swap(
            fromToken,
            toToken,
            withdrawnAmount,
            swapCalldata
        );

        if (swappedAmount < minOutputAmount) {
            revert InsufficientOutputAmount();
        }

        _depositToFleet(toFleetCommander, toToken, swappedAmount, msg.sender);
    }

    function _depositToFleet(
        IFleetCommander fleet,
        IERC20 fleetToken,
        uint256 amount,
        address receiver
    ) internal {
        fleetToken.forceApprove(address(fleet), amount);
        fleet.deposit(amount, receiver);
    }

    function _withdrawFromFleet(
        IFleetCommander fleet,
        uint256 amount,
        address owner
    ) internal returns (uint256) {
        return fleet.withdraw(amount, address(this), owner);
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
        return parseSwapReturnData(swapCalldata, returnData);
    }

    function parseSwapReturnData(
        bytes calldata swapCalldata,
        bytes memory returnData
    ) internal pure returns (uint256) {
        bytes4 selector = bytes4(swapCalldata[:4]);

        if (selector == SWAP_SELECTOR) {
            (uint256 returnAmount, uint256 spentAmount) = abi.decode(
                returnData,
                (uint256, uint256)
            );
            return returnAmount;
        } else if (
            selector == UNOSWAP_SELECTOR || selector == UNISWAP_V3_SWAP_SELECTOR
        ) {
            return abi.decode(returnData, (uint256));
        } else {
            revert UnsupportedSwapFunction();
        }
    }
}
