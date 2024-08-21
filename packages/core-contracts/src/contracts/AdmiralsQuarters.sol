// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
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

contract AdmiralsQuarters is Ownable {
    using SafeERC20 for IERC20;

    address public immutable oneInchRouter;

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
        require(
            fleetCommanders.length == allocations.length,
            "Mismatched input lengths"
        );
        require(
            fleetCommanders.length == swapCalldatas.length,
            "Mismatched swap calldata length"
        );
        require(fleetCommanders.length > 0, "No fleets provided");

        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            totalAllocation += allocations[i];
        }

        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);

        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            IFleetCommander fleet = IFleetCommander(fleetCommanders[i]);
            IERC20 fleetToken = IERC20(fleet.asset());
            uint256 fleetAllocation = (inputAmount * allocations[i]) /
                totalAllocation;

            uint256 amountToDeposit;
            if (swapCalldatas[i].length > 0) {
                inputToken.forceApprove(oneInchRouter, fleetAllocation);
                (bool success, bytes memory returnData) = oneInchRouter.call(
                    swapCalldatas[i]
                );
                require(success, "Swap failed");
                amountToDeposit = abi.decode(returnData, (uint256));
            } else {
                // If no swap is needed, use the allocation directly
                amountToDeposit = fleetAllocation;
            }

            fleetToken.forceApprove(address(fleet), amountToDeposit);
            fleet.deposit(amountToDeposit, msg.sender);
        }
    }

    function exitFleets(
        address[] calldata fleetCommanders,
        uint256[] calldata shareAmounts,
        IERC20 outputToken,
        uint256 minOutputAmount,
        bytes[] calldata swapCalldatas
    ) external {
        require(
            fleetCommanders.length == shareAmounts.length,
            "Mismatched input lengths"
        );
        require(
            fleetCommanders.length == swapCalldatas.length,
            "Mismatched swap calldata length"
        );
        require(fleetCommanders.length > 0, "No fleets provided");

        uint256 totalOutputAmount = 0;

        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            IFleetCommander fleet = IFleetCommander(fleetCommanders[i]);
            IERC20 fleetToken = IERC20(fleet.asset());

            uint256 fleetTokenReceived = fleet.withdraw(
                shareAmounts[i],
                address(this),
                msg.sender
            );

            if (swapCalldatas[i].length > 0) {
                // Swap is needed
                fleetToken.forceApprove(oneInchRouter, fleetTokenReceived);
                console.log("xxxx");
                (bool success, bytes memory returnData) = oneInchRouter.call(
                    swapCalldatas[i]
                );
                require(success, "Swap failed");
                uint256 returnAmount = abi.decode(returnData, (uint256));
                totalOutputAmount += returnAmount;
            } else {
                // No swap needed, add directly to total if it's the output token
                if (address(fleetToken) == address(outputToken)) {
                    totalOutputAmount += fleetTokenReceived;
                } else {
                    revert("Asset mismatch: swap needed but not provided");
                }
            }
        }

        require(
            totalOutputAmount >= minOutputAmount,
            "Insufficient output amount"
        );
        outputToken.safeTransfer(msg.sender, totalOutputAmount);
    }
}
