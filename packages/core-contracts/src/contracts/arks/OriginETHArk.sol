// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IOriginETH} from "../../interfaces/origin/IOriginETH.sol";

/**
 * @title OriginETHArk
 * @notice Ark contract for managing WETH deposits into Origin ETH protocol
 * @dev Implements strategy for depositing WETH into Origin ETH, withdrawing tokens (to be implemented), and tracking yield
 */
contract OriginETHArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Origin ETH contract this Ark interacts with
    IOriginETH public immutable originETH;

    /// @notice The WETH token address
    address public immutable weth;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the OriginETHArk
     * @param _originETH Address of the OriginETH contract
     * @param _weth Address of the WETH token
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _originETH,
        address _weth,
        ArkParams memory _params
    ) Ark(_params) {
        if (_originETH == address(0)) {
            revert InvalidOriginETHAddress();
        }

        if (_weth == address(0)) {
            revert InvalidWethAddress();
        }

        // Ensure the asset in params is WETH
        if (address(config.asset) != _weth) {
            revert AssetMismatch();
        }

        originETH = IOriginETH(_originETH);
        weth = _weth;

        // Approve Origin ETH to spend the Ark's WETH tokens
        config.asset.forceApprove(_originETH, Constants.MAX_UINT256);
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Origin ETH protocol
     * @return assets The total balance of underlying assets held in the vault for this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        // For now, just return the WETH balance, since we haven't implemented redemption
        // In a complete implementation, this would need to track the value of Origin ETH shares
        return config.asset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev OriginETHArk doesn't implement withdrawal yet, so return 0
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        return 0; // No withdrawal implementation yet
    }

    /**
     * @notice Deposits WETH into the Origin ETH protocol
     * @param amount The amount of WETH to deposit
     * @param /// data Additional data (can be used to specify minShares parameter)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Call Origin ETH's mint function with the specified parameters
        config.asset.approve(address(originETH), amount);
        originETH.mint(address(config.asset), amount, amount);
    }

    /**
     * @notice Withdraws assets from the Origin ETH protocol (not implemented yet)
     * @param amount The amount of assets to withdraw
     * @param data Additional data (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata data) internal override {
        // Not implemented yet
        revert WithdrawalNotImplemented();
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev This function is a no-op as Origin ETH auto-compounds the rewards
     * @param data Additional data (unused in this implementation)
     * @return rewardTokens The addresses of the reward tokens (empty array in this case)
     * @return rewardAmounts The amounts of the reward tokens (empty array in this case)
     */
    function _harvest(
        bytes calldata data
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(0);
        rewardAmounts[0] = 0;
    }

    /**
     * @notice Validates the board data
     * @dev The data can be empty or contain a uint256 for minShares
     * @param data Additional data to validate
     */
    function _validateBoardData(bytes calldata data) internal pure override {
        if (data.length > 0) {
            // Ensure data is properly encoded as a uint256
            abi.decode(data, (uint256));
        }
    }

    /**
     * @notice Validates the disembark data
     * @dev Not implemented yet
     * @param data Additional data to validate
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        // No validation needed as disembark is not implemented
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when an invalid WETH address is provided
    error InvalidWethAddress();

    /// @notice Error thrown when the asset in ArkParams doesn't match WETH
    error AssetMismatch();

    /// @notice Error thrown when withdrawal is attempted (not implemented yet)
    error WithdrawalNotImplemented();

    /// @notice Error thrown when an invalid Origin ETH address is provided
    error InvalidOriginETHAddress();
}
