// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {ISummerToken} from "../interfaces/ISummerToken.sol";

import {SummerVestingWallet} from "./SummerVestingWallet.sol";

contract SummerToken is
    OFT,
    ERC20Burnable,
    ERC20Votes,
    ERC20Permit,
    ISummerToken
{
    uint256 private constant INITIAL_SUPPLY = 1e9;
    mapping(address owner => address vestingWallet) public vestingWallets;

    constructor(
        TokenParams memory params
    )
        OFT(params.name, params.symbol, params.lzEndpoint, params.governor)
        ERC20Permit(params.name)
        Ownable(params.governor)
    {}

    /**
     * @dev Creates a new vesting wallet for a beneficiary
     * @param beneficiary Address of the beneficiary to whom vested tokens are transferred
     * @param timeBasedAmount Amount of tokens to be vested based on time
     * @param goalAmounts Array of token amounts to be vested based on performance goals
     * @param vestingType Type of vesting schedule (TeamVesting or InvestorExTeamVesting)
     * @custom:requirements
     * - The beneficiary must not already have a vesting wallet
     * - The caller must have sufficient balance to transfer the total vesting amount
     * @custom:effects
     * - Creates a new SummerVestingWallet contract
     * - Stores the new vesting wallet address in the vestingWallets mapping
     * - Transfers the total vesting amount from the caller to the new vesting wallet
     * @custom:emits No events are directly emitted, but a token transfer occurs
     * @custom:security-considerations
     * - Ensure that only authorized addresses can call this function
     * - Verify that the vestingType is valid before creating the wallet
     * - Consider implementing a maximum limit for goalAmounts to prevent excessive gas costs
     * @custom:gas-considerations
     * - The gas cost increases with the number of goal amounts
     * - Creating a new contract (SummerVestingWallet) is a relatively expensive operation
     */
    function createVestingWallet(
        address beneficiary,
        uint256 timeBasedAmount,
        uint256[] memory goalAmounts,
        SummerVestingWallet.VestingType vestingType
    ) external {
        if (vestingWallets[beneficiary] != address(0)) {
            revert VestingWalletAlreadyExists(beneficiary);
        }

        uint64 startTimestamp = uint64(block.timestamp);
        uint64 durationSeconds = 730 days; // 2 years for both vesting types

        uint256 totalAmount = timeBasedAmount;
        for (uint256 i = 0; i < goalAmounts.length; i++) {
            totalAmount += goalAmounts[i];
        }

        address newVestingWallet = address(
            new SummerVestingWallet(
                address(this),
                beneficiary,
                startTimestamp,
                durationSeconds,
                vestingType,
                timeBasedAmount,
                goalAmounts,
                msg.sender // Set the caller as the admin
            )
        );
        vestingWallets[beneficiary] = newVestingWallet;

        _transfer(msg.sender, newVestingWallet, totalAmount);
    }

    /*
     * @dev Overrides the nonces function to resolve conflicts between ERC20Permit and Nonces.
     * @param owner The address to check nonces for.
     * @return The current nonce for the given address.
     */
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /*
     * @dev Internal function to update token balances.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    )
        internal
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(
            _amountLD,
            _minAmountLD,
            _dstEid
        );

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Overrides the default _getVotingUnits function to include all user tokens in voting power, including locked up tokens in vesting wallets
     * @param account The address to get voting units for
     * @return uint256 The total number of voting units for the account
     * @custom:internal-logic
     * - Retrieves the direct token balance of the account
     * - Checks if the account has an associated vesting wallet
     * - If a vesting wallet exists, adds its balance to the account's direct balance
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensures that tokens in vesting contracts still contribute to voting power
     * - May increase the voting power of accounts with vesting wallets compared to standard ERC20Votes implementation
     * - Consider the implications of this increased voting power on governance decisions
     * @custom:gas-considerations
     * - This function performs an additional storage read and potential balance check compared to the standard implementation
     * - May slightly increase gas costs for voting-related operations
     */
    function _getVotingUnits(
        address account
    ) internal view override returns (uint256) {
        uint256 directBalance = balanceOf(account);
        address vestingWalletAddress = vestingWallets[account];

        if (vestingWalletAddress != address(0)) {
            uint256 vestingWalletBalance = balanceOf(vestingWalletAddress);
            return directBalance + vestingWalletBalance;
        }

        return directBalance;
    }

    /**
     * @notice Mints new tokens and assigns them to the specified address
     * @dev This function can only be called by the contract owner
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     * @custom:requirements
     * - The caller must be the contract owner
     * @custom:effects
     * - Increases the total supply of tokens
     * - Increases the balance of the recipient address
     * @custom:emits A Transfer event from the zero address to the recipient
     * @custom:security-considerations
     * - This function allows the owner to arbitrarily increase the token supply
     * - Ensure that the owner address is properly secured and trusted
     * - Consider implementing additional checks or limits on minting to prevent abuse
     * - there is no cap on the minting of tokens
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Error thrown when attempting to create a vesting wallet for an address that already has one
     * @param beneficiary The address for which a vesting wallet already exists
     */
    error VestingWalletAlreadyExists(address beneficiary);

    /**
     * @dev Error thrown when an invalid vesting type is provided
     * @param invalidType The invalid vesting type that was provided
     */
    error InvalidVestingType(SummerVestingWallet.VestingType invalidType);
}
