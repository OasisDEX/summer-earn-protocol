// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICrossChainConfigManaged
 * @notice Interface for contracts that need to read from the CrossChainConfigManager
 */
interface ICrossChainConfigManaged {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the CrossChainConfigManager address is zero
    error CrossChainConfigManagerZeroAddress();

    /// @notice Thrown when the caller is not an executor
    error OnlyAuthorizedExecutor();

    /// @notice Thrown when the caller is not the bridge router
    error OnlyBridgeRouter();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the bridge router contract
    function bridgeRouter() external view returns (address);

    /// @notice Returns the address of the cross chain registry contract
    function crossChainRegistry() external view returns (address);

    /// @notice Returns the gas limit for cross-chain messages
    function defaultGasLimit() external view returns (uint256);

    /// @notice Returns true if the given address is an executor
    function isExecutor(address executor) external view returns (bool);
}
