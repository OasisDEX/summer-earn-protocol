// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

interface IAggregationRouterV5 {
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(
        address executor,
        SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount);
}

contract AdmiralsQuarters is Ownable {
    using SafeERC20 for IERC20;

    IAggregationRouterV5 public oneInchRouter;

    constructor(address _oneInchRouter) Ownable(msg.sender) {
        oneInchRouter = IAggregationRouterV5(_oneInchRouter);
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

            inputToken.forceApprove(address(oneInchRouter), fleetAllocation);

            (uint256 returnAmount, ) = oneInchRouter.swap(
                address(this),
                IAggregationRouterV5.SwapDescription({
                    srcToken: inputToken,
                    dstToken: fleetToken,
                    srcReceiver: payable(address(this)),
                    dstReceiver: payable(address(this)),
                    amount: fleetAllocation,
                    minReturnAmount: 0, // Set appropriate slippage protection
                    flags: 0
                }),
                "",
                swapCalldatas[i]
            );

            fleetToken.forceApprove(address(fleet), returnAmount);
            fleet.deposit(returnAmount, msg.sender);
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
            fleetToken.forceApprove(address(oneInchRouter), fleetTokenReceived);

            (uint256 returnAmount, ) = oneInchRouter.swap(
                address(this),
                IAggregationRouterV5.SwapDescription({
                    srcToken: fleetToken,
                    dstToken: outputToken,
                    srcReceiver: payable(address(this)),
                    dstReceiver: payable(address(this)),
                    amount: fleetTokenReceived,
                    minReturnAmount: 0, // Set appropriate slippage protection
                    flags: 0
                }),
                "",
                swapCalldatas[i]
            );

            totalOutputAmount += returnAmount;
        }

        require(
            totalOutputAmount >= minOutputAmount,
            "Insufficient output amount"
        );
        outputToken.safeTransfer(msg.sender, totalOutputAmount);
    }
}
