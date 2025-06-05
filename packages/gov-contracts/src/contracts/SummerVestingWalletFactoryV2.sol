// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISummerVestingWalletFactoryV2} from "../interfaces/ISummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../interfaces/ISummerVestingWalletV2.sol";
import {SummerVestingWalletV2} from "../contracts/SummerVestingWalletV2.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title SummerVestingWalletFactoryV2
 * @notice Factory contract for creating new SummerVestingWalletV2 instances
 * @dev Creates and tracks vesting wallets with configurable parameters
 */
contract SummerVestingWalletFactoryV2 is
    ISummerVestingWalletFactoryV2,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////
    ///             STATE VARIABLES            ///
    //////////////////////////////////////////////

    /** @notice The ERC20 token that will be vested */
    address public immutable token;

    /** @notice Mapping from beneficiary address to their vesting wallet address */
    mapping(address beneficiary => address vestingWallet) public vestingWallets;

    /** @notice Mapping from vesting wallet address to its beneficiary address */
    mapping(address vestingWallet => address beneficiary) public vestingWalletOwners;

    //////////////////////////////////////////////
    ///              CONSTRUCTOR               ///
    //////////////////////////////////////////////

    /**
     * @notice Initializes the factory with the token to be vested
     * @param _token The address of the ERC20 token that will be vested
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(
        address _token,
        address _accessManager
    ) ProtocolAccessManaged(_accessManager) {
        if (_token == address(0)) revert ZeroTokenAddress();
        token = _token;
    }

    //////////////////////////////////////////////
    ///           EXTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWalletFactoryV2
    function createVestingWallet(
        address beneficiary,
        ISummerVestingWalletV2.VestingParams memory vestingParams,
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals
    ) external onlyFoundation returns (address newVestingWallet) {
        if (vestingWallets[beneficiary] != address(0)) {
            revert VestingWalletAlreadyExists(beneficiary);
        }

        // Calculate total amount needed
        uint256 totalAmount = vestingParams.cliffAmount + vestingParams.totalVestingAmount;
        for (uint256 i = 0; i < performanceGoals.length; i++) {
            totalAmount += performanceGoals[i].amount;
        }

        // Check allowance and balance
        IERC20 tokenContract = IERC20(token);
        uint256 allowance = tokenContract.allowance(msg.sender, address(this));
        if (allowance < totalAmount) {
            revert InsufficientAllowance(totalAmount, allowance);
        }

        uint256 senderBalance = tokenContract.balanceOf(msg.sender);
        if (senderBalance < totalAmount) {
            revert InsufficientBalance(totalAmount, senderBalance);
        }

        // Create new vesting wallet
        newVestingWallet = address(
            new SummerVestingWalletV2(
                token,
                beneficiary,
                vestingParams,
                performanceGoals,
                address(_accessManager)
            )
        );

        // Update mappings
        vestingWallets[beneficiary] = newVestingWallet;
        vestingWalletOwners[newVestingWallet] = beneficiary;

        // Transfer tokens to vesting wallet
        uint256 preBalance = tokenContract.balanceOf(newVestingWallet);
        tokenContract.safeTransferFrom(msg.sender, newVestingWallet, totalAmount);
        uint256 postBalance = tokenContract.balanceOf(newVestingWallet);

        if (postBalance != preBalance + totalAmount) {
            revert TransferAmountMismatch(preBalance + totalAmount, postBalance);
        }

        emit VestingWalletCreated(
            beneficiary,
            newVestingWallet,
            vestingParams,
            performanceGoals.length
        );
    }
} 