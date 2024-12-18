// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ark, ArkParams} from "../../src/contracts/Ark.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RestictedWithdrawalArkMock
 * @notice A mock implementation of the Ark contract for testing purposes
 * @dev This contract simulates an Ark with configurable withdrawal restrictions and data validation
 */
contract RestictedWithdrawalArkMock is Ark {
    // State variables
    uint256 public mockRate;
    mapping(address => uint256) public userBalances;

    constructor(ArkParams memory _params) Ark(_params) {
        mockRate = 1e18; // Initialize with a 1:1 rate
    }

    /**
     * @notice Set a mock rate for testing purposes
     * @param _rate The new mock rate to set
     */
    function setMockRate(uint256 _rate) external {
        mockRate = _rate;
    }

    /**
     * @notice Returns the total assets held by this Ark
     * @return The total token balance of this contract
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(config.asset).balanceOf(address(this));
    }

    function _withdrawableTotalAssets()
        internal
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    /**
     * @notice Simulates boarding (depositing) assets into the Ark
     * @param amount The amount of assets to board
     * @param // data Additional data for boarding (must be a uint256 for this mock)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        userBalances[msg.sender] += amount;
    }

    /**
     * @notice Simulates disembarking (withdrawing) assets from the Ark
     * @param amount The amount of assets to disembark
     * @param /// data Additional data for disembarking (must be a uint256 for this mock)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        require(userBalances[msg.sender] >= amount, "Insufficient balance");
        userBalances[msg.sender] -= amount;
    }

    /**
     * @notice Simulates harvesting rewards
     * @param data Additional data for harvesting (must be a uint256 for this mock)
     * @return rewardTokens The address of the reward token
     * @return rewardAmounts The amount of rewards harvested
     */
    function _harvest(
        bytes calldata data
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        (rewardTokens[0], rewardAmounts[0]) = abi.decode(
            data,
            (address, uint256)
        );
        IERC20(rewardTokens[0]).transfer(msg.sender, rewardAmounts[0]);
    }

    /**
     * @notice Validates the board data
     * @param data The board data to validate (must be a uint256 for this mock)
     */
    function _validateBoardData(bytes calldata data) internal pure override {
        if (data.length != 32) {
            revert InvalidBoardData();
        }
        // Additional validation can be added here if needed
    }

    /**
     * @notice Validates the disembark data
     * @param data The disembark data to validate (must be a uint256 for this mock)
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        if (data.length != 32) {
            revert InvalidDisembarkData();
        }
        // Additional validation can be added here if needed
    }

    function testSkipper() public {}
}
