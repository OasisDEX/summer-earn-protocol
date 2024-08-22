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

/**
 * @title AdmiralsQuarters
 * @notice A contract for managing multiple FleetCommander instances and performing swaps using 1inch
 * @dev This contract allows users to enter, exit, and move between different fleets, optionally performing swaps
 */
contract AdmiralsQuarters is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The address of the 1inch router contract
    address public immutable oneInchRouter;

    // 1inch function selectors
    bytes4 private constant SWAP_SELECTOR = 0x07ed2379;
    bytes4 private constant UNOSWAP_SELECTOR = 0x83800a8e;
    bytes4 private constant UNOSWAP_2_SELECTOR = 0x8770ba91;
    bytes4 private constant UNOSWAP_3_SWAP_SELECTOR = 0x19367472;

    // Custom errors
    error MismatchedInputLengths();
    error NoFleetsProvided();
    error SwapFailed();
    error AssetMismatch();
    error InsufficientOutputAmount();
    error UnsupportedSwapFunction();
    error InvalidAddress();
    error ZeroAmount();

    // Events
    event FleetEntered(
        address indexed user,
        address indexed fleet,
        uint256 amount,
        uint256 shares
    );
    event FleetExited(
        address indexed user,
        address indexed fleet,
        uint256 amount,
        uint256 shares
    );
    event FleetMoved(
        address indexed user,
        address indexed fromFleet,
        address indexed toFleet,
        uint256 amount
    );
    event Swapped(
        address indexed fromToken,
        address indexed toToken,
        uint256 fromAmount,
        uint256 toAmount
    );

    /**
     * @dev Custom nonReentrant modifier using transient storage
     */
    modifier nonReentrant() {
        assembly {
            if tload(0) {
                mstore(0x00, 0x8beb9d16) // bytes4(keccak256("ReentrancyGuard()"))
                revert(0x00, 0x04)
            }
            tstore(0, 1)
        }
        _;
        assembly {
            tstore(0, 0)
        }
    }

    /**
     * @notice Initializes the AdmiralsQuarters contract
     * @param _oneInchRouter The address of the 1inch router contract
     */
    constructor(address _oneInchRouter) Ownable(msg.sender) {
        if (_oneInchRouter == address(0)) revert InvalidAddress();
        oneInchRouter = _oneInchRouter;
    }

    /**
     * @notice Allows users to enter multiple fleets with a single token input
     * @param fleetCommanders Array of FleetCommander addresses to enter
     * @param allocations Array of allocation ratios for each fleet
     * @param inputToken The token used for entry
     * @param inputAmount The total amount of inputToken to use
     * @param swapCalldatas Array of 1inch swap calldatas for each fleet entry
     */
    function enterFleets(
        address[] calldata fleetCommanders,
        uint256[] calldata allocations,
        IERC20 inputToken,
        uint256 inputAmount,
        bytes[] calldata swapCalldatas
    ) external nonReentrant {
        if (
            fleetCommanders.length != allocations.length ||
            fleetCommanders.length != swapCalldatas.length
        ) {
            revert MismatchedInputLengths();
        }
        if (fleetCommanders.length == 0) revert NoFleetsProvided();
        if (inputAmount == 0) revert ZeroAmount();

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
            uint256 shares = _depositToFleet(
                fleet,
                fleetToken,
                swappedAmount,
                msg.sender
            );

            emit FleetEntered(
                msg.sender,
                address(fleet),
                swappedAmount,
                shares
            );
        }
    }

    /**
     * @notice Allows users to exit multiple fleets and receive a single output token
     * @param fleetCommanders Array of FleetCommander addresses to exit
     * @param tokenAmounts Array of token amounts to withdraw from each fleet
     * @param outputToken The desired output token
     * @param minOutputAmount The minimum acceptable amount of outputToken
     * @param swapCalldatas Array of 1inch swap calldatas for each fleet exit
     */
    function exitFleets(
        address[] calldata fleetCommanders,
        uint256[] calldata tokenAmounts,
        IERC20 outputToken,
        uint256 minOutputAmount,
        bytes[] calldata swapCalldatas
    ) external nonReentrant {
        if (
            fleetCommanders.length != tokenAmounts.length ||
            fleetCommanders.length != swapCalldatas.length
        ) {
            revert MismatchedInputLengths();
        }
        if (fleetCommanders.length == 0) revert NoFleetsProvided();

        uint256 totalOutputAmount = 0;

        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            IFleetCommander fleet = IFleetCommander(fleetCommanders[i]);
            IERC20 fleetToken = IERC20(fleet.asset());

            uint256 sharesRedeemed = _withdrawFromFleet(
                fleet,
                tokenAmounts[i],
                msg.sender
            );
            uint256 swappedAmount = _swap(
                fleetToken,
                outputToken,
                sharesRedeemed,
                swapCalldatas[i]
            );
            totalOutputAmount += swappedAmount;

            emit FleetExited(
                msg.sender,
                address(fleet),
                sharesRedeemed,
                tokenAmounts[i]
            );
        }

        if (totalOutputAmount < minOutputAmount)
            revert InsufficientOutputAmount();
        outputToken.safeTransfer(msg.sender, totalOutputAmount);
    }

    /**
     * @notice Allows users to move assets from one fleet to another
     * @param fromFleet The address of the source FleetCommander
     * @param toFleet The address of the destination FleetCommander
     * @param assetAmount The amount of assets to move from the source fleet
     * @param minOutputAmount The minimum acceptable amount of tokens in the destination fleet
     * @param swapCalldata The 1inch swap calldata for converting between fleet tokens
     */
    function moveFleets(
        address fromFleet,
        address toFleet,
        uint256 assetAmount,
        uint256 minOutputAmount,
        bytes calldata swapCalldata
    ) external nonReentrant {
        if (fromFleet == address(0) || toFleet == address(0))
            revert InvalidAddress();
        if (assetAmount == 0) revert ZeroAmount();

        IFleetCommander fromFleetCommander = IFleetCommander(fromFleet);
        IFleetCommander toFleetCommander = IFleetCommander(toFleet);
        IERC20 fromToken = IERC20(fromFleetCommander.asset());
        IERC20 toToken = IERC20(toFleetCommander.asset());

        _withdrawFromFleet(fromFleetCommander, assetAmount, msg.sender);
        uint256 swappedAmount = _swap(
            fromToken,
            toToken,
            assetAmount,
            swapCalldata
        );

        if (swappedAmount < minOutputAmount) revert InsufficientOutputAmount();

        _depositToFleet(toFleetCommander, toToken, swappedAmount, msg.sender);

        emit FleetMoved(msg.sender, fromFleet, toFleet, swappedAmount);
    }

    /**
     * @dev Internal function to deposit tokens into a fleet
     * @param fleet The FleetCommander to deposit into
     * @param fleetToken The token accepted by the fleet
     * @param amount The amount of tokens to deposit
     * @param receiver The address to receive the fleet shares
     * @return shares The number of shares received from the deposit
     */
    function _depositToFleet(
        IFleetCommander fleet,
        IERC20 fleetToken,
        uint256 amount,
        address receiver
    ) internal returns (uint256 shares) {
        fleetToken.forceApprove(address(fleet), amount);
        shares = fleet.deposit(amount, receiver);
    }

    /**
     * @dev Internal function to withdraw tokens from a fleet
     * @param fleet The FleetCommander to withdraw from
     * @param amount The amount of shares to withdraw
     * @param owner The owner of the shares redeemed
     */
    function _withdrawFromFleet(
        IFleetCommander fleet,
        uint256 amount,
        address owner
    ) internal returns (uint256 shares) {
        shares = fleet.withdraw(amount, address(this), owner);
    }

    /**
     * @dev Internal function to perform a token swap using 1inch
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amount The amount of fromToken to swap
     * @param swapCalldata The 1inch swap calldata
     * @return swappedAmount The amount of toToken received from the swap
     */
    function _swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        bytes calldata swapCalldata
    ) internal returns (uint256 swappedAmount) {
        if (swapCalldata.length == 0) {
            if (address(fromToken) != address(toToken)) revert AssetMismatch();
            return amount;
        }

        uint256 balanceBefore = toToken.balanceOf(address(this));

        fromToken.forceApprove(oneInchRouter, amount);
        (bool success, bytes memory returnData) = oneInchRouter.call(
            swapCalldata
        );
        if (!success) revert SwapFailed();

        uint256 balanceAfter = toToken.balanceOf(address(this));
        swappedAmount = balanceAfter - balanceBefore;

        uint256 returnedAmount = parseSwapReturnData(swapCalldata, returnData);
        require(swappedAmount == returnedAmount, "Swap amount mismatch");

        emit Swapped(
            address(fromToken),
            address(toToken),
            amount,
            swappedAmount
        );
        return swappedAmount;
    }

    /**
     * @dev Internal function to parse the return data from 1inch swaps
     * @param swapCalldata The original swap calldata
     * @param returnData The return data from the swap call
     * @return The amount of tokens received from the swap
     */
    function parseSwapReturnData(
        bytes calldata swapCalldata,
        bytes memory returnData
    ) internal pure returns (uint256) {
        bytes4 selector = bytes4(swapCalldata[:4]);

        if (selector == SWAP_SELECTOR) {
            (uint256 returnAmount, ) = abi.decode(
                returnData,
                (uint256, uint256)
            );
            return returnAmount;
        } else if (
            selector == UNOSWAP_SELECTOR ||
            selector == UNOSWAP_2_SELECTOR ||
            selector == UNOSWAP_3_SWAP_SELECTOR
        ) {
            return abi.decode(returnData, (uint256));
        } else {
            revert UnsupportedSwapFunction();
        }
    }

    /**
     * @notice Allows the owner to rescue any ERC20 tokens sent to the contract by mistake
     * @param token The ERC20 token to rescue
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to rescue
     */
    function rescueTokens(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
