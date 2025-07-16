// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IFleetCommanderMinimal
 * @notice Minimal interface for FleetCommander contracts used in cross-chain deposits
 * @dev Contains only the essential methods needed for bridge operations
 */
interface IFleetCommanderMinimal {
    /**
     * @notice Deposits assets to the FleetCommander with referral code
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive the shares
     * @param referralCode Referral code for tracking
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) external returns (uint256 shares);

    /**
     * @notice Deposits assets to the FleetCommander without referral code
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive the shares
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /**
     * @notice Returns the underlying asset of this FleetCommander
     * @return Asset address
     */
    function asset() external view returns (address);

    /**
     * @notice Returns the maximum amount that can be deposited for an owner
     * @param owner Address to check deposit limit for
     * @return Maximum deposit amount
     */
    function maxDeposit(address owner) external view returns (uint256);
}
