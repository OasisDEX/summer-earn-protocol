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

/**
 * @title AdmiralsQuartersMulticall
 * @dev A contract for managing deposits and withdrawals to/from FleetCommander contracts,
 *      with integrated swapping functionality using 1inch Router.
 * @notice This contract uses a custom nonReentrant modifier with transient storage for gas efficiency.
 */
contract AdmiralsQuartersMulticall is Ownable, Multicall {
    using SafeERC20 for IERC20;

    address public immutable oneInchRouter;

    // 1inch function selectors
    bytes4 private constant SWAP_SELECTOR = 0x07ed2379;
    bytes4 private constant UNOSWAP_SELECTOR = 0x83800a8e;
    bytes4 private constant UNOSWAP_2_SELECTOR = 0x8770ba91;
    bytes4 private constant UNOSWAP_3_SWAP_SELECTOR = 0x19367472;

    // Events
    event TokensDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event TokensWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event FleetEntered(
        address indexed user,
        address indexed fleetCommander,
        uint256 inputAmount,
        uint256 sharesReceived
    );
    event FleetExited(
        address indexed user,
        address indexed fleetCommander,
        uint256 withdrawnAmount,
        uint256 outputAmount
    );
    event Swapped(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 fromAmount,
        uint256 toAmount
    );
    event TokensRescued(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // Custom errors
    error SwapFailed();
    error AssetMismatch();
    error InsufficientOutputAmount();
    error InvalidFleetCommander();
    error InvalidToken();
    error UnsupportedSwapFunction();
    error SwapAmountMismatch();
    error ReentrancyGuard();
    error ZeroAmount();

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

    constructor(address _oneInchRouter) Ownable(msg.sender) {
        require(_oneInchRouter != address(0), "Invalid 1inch Router address");
        oneInchRouter = _oneInchRouter;
    }

    /**
     * @notice Deposits tokens into the contract
     * @param asset The token to be deposited
     * @param amount The amount of tokens to deposit
     */
    function depositTokens(IERC20 asset, uint256 amount) external nonReentrant {
        if (address(asset) == address(0)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(msg.sender, address(asset), amount);
    }

    /**
     * @notice Withdraws tokens from the contract
     * @param asset The token to be withdrawn
     * @param amount The amount of tokens to withdraw (0 for all)
     */
    function withdrawTokens(
        IERC20 asset,
        uint256 amount
    ) external nonReentrant {
        if (address(asset) == address(0)) revert InvalidToken();
        if (amount == 0) {
            amount = asset.balanceOf(address(this));
        }

        asset.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, address(asset), amount);
    }

    /**
     * @notice Enters a FleetCommander by depositing tokens
     * @param fleetCommander The address of the FleetCommander contract
     * @param inputToken The token to be deposited
     * @param amount The amount of inputToken to be deposited (0 for all)
     * @return shares The number of shares received from the FleetCommander
     */
    function enterFleet(
        address fleetCommander,
        IERC20 inputToken,
        uint256 amount
    ) external nonReentrant returns (uint256 shares) {
        if (fleetCommander == address(0)) revert InvalidFleetCommander();
        if (address(inputToken) == address(0)) revert InvalidToken();

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetToken = IERC20(fleet.asset());

        uint256 balance = inputToken.balanceOf(address(this));
        uint256 depositAmount = amount == 0 ? balance : amount;
        if (depositAmount > balance) revert InsufficientOutputAmount();

        fleetToken.forceApprove(address(fleet), depositAmount);
        shares = fleet.deposit(depositAmount, msg.sender);

        emit FleetEntered(msg.sender, fleetCommander, depositAmount, shares);
    }

    /**
     * @notice Exits a FleetCommander by withdrawing tokens
     * @dev If all tokens are withdrawn - remember to to return the difference between swapped and actual amount
     * @param fleetCommander The address of the FleetCommander contract
     * @param amount The amount of shares to withdraw (0 for all)
     * @return assets The amount of assets received from the FleetCommander
     */
    function exitFleet(
        address fleetCommander,
        uint256 amount
    ) external nonReentrant returns (uint256 assets) {
        if (fleetCommander == address(0)) revert InvalidFleetCommander();

        IFleetCommander fleet = IFleetCommander(fleetCommander);

        uint256 withdrawAmount = amount == 0 ? type(uint256).max : amount;

        assets = fleet.withdraw(withdrawAmount, address(this), msg.sender);

        emit FleetExited(msg.sender, fleetCommander, withdrawAmount, assets);
    }

    /**
     * @notice Performs a token swap using 1inch Router
     * @dev The tokens stay in the contract after the swap
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amount The amount of fromToken to swap
     * @param swapCalldata The calldata for the 1inch swap
     * @return swappedAmount The amount of toToken received after the swap
     */
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        bytes calldata swapCalldata
    ) external nonReentrant returns (uint256 swappedAmount) {
        if (address(fromToken) == address(0) || address(toToken) == address(0))
            revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        swappedAmount = _swap(fromToken, toToken, amount, swapCalldata);

        emit Swapped(
            msg.sender,
            address(fromToken),
            address(toToken),
            amount,
            swappedAmount
        );
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
            if (address(fromToken) != address(toToken)) {
                revert AssetMismatch();
            }
            return amount;
        }

        uint256 balanceBefore = toToken.balanceOf(address(this));

        fromToken.forceApprove(oneInchRouter, amount);
        (bool success, bytes memory returnData) = oneInchRouter.call(
            swapCalldata
        );
        if (!success) {
            revert SwapFailed();
        }

        uint256 balanceAfter = toToken.balanceOf(address(this));
        uint256 actualSwappedAmount = balanceAfter - balanceBefore;

        swappedAmount = parseSwapReturnData(swapCalldata, returnData);
        if (swappedAmount != actualSwappedAmount) {
            revert SwapAmountMismatch();
        }
    }

    /**
     * @dev Internal function to parse the return data from 1inch swaps
     * @param swapCalldata The original swap calldata
     * @param returnData The return data from the swap call
     * @return swappedAmount The amount of tokens received from the swap
     */
    function parseSwapReturnData(
        bytes calldata swapCalldata,
        bytes memory returnData
    ) internal pure returns (uint256 swappedAmount) {
        bytes4 selector = bytes4(swapCalldata[:4]);

        if (selector == SWAP_SELECTOR) {
            (uint256 returnAmount, ) = abi.decode(
                returnData,
                (uint256, uint256)
            );
            swappedAmount = returnAmount;
        } else if (
            selector == UNOSWAP_SELECTOR ||
            selector == UNOSWAP_2_SELECTOR ||
            selector == UNOSWAP_3_SWAP_SELECTOR
        ) {
            swappedAmount = abi.decode(returnData, (uint256));
        } else {
            revert UnsupportedSwapFunction();
        }
    }

    /**
     * @notice Allows the owner to rescue any ERC20 tokens sent to the contract by mistake
     * @param token The address of the ERC20 token to rescue
     * @param to The address to send the rescued tokens to
     * @param amount The amount of tokens to rescue
     */
    function rescueTokens(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(to, amount);
        emit TokensRescued(address(token), to, amount);
    }
}
