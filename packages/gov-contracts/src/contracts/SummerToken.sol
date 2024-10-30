// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {SummerVestingWallet} from "./SummerVestingWallet.sol";
import {IGovernanceRewardsManager} from "@summerfi/protocol-interfaces/IGovernanceRewardsManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/src/VotingDecayManager.sol";

/**
 * @title SummerToken
 * @dev Implementation of the Summer governance token with vesting, cross-chain, and voting decay capabilities.
 * @custom:security-contact security@summer.fi
 */
contract SummerToken is
    OFT,
    ERC20Burnable,
    ERC20Votes,
    ERC20Permit,
    VotingDecayManager,
    ISummerToken
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant INITIAL_SUPPLY = 1e9;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address owner => address vestingWallet) public vestingWallets;
    IGovernanceRewardsManager public rewardsManager;
    ISummerGovernor public governor;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyGovernor() {
        if (address(governor) == address(0)) {
            revert GovernorNotSet();
        }

        if (_msgSender() != address(governor)) {
            revert SummerGovernorInvalidCaller();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        TokenParams memory params
    )
        OFT(params.name, params.symbol, params.lzEndpoint, params.governor)
        ERC20Permit(params.name)
        VotingDecayManager(
            params.initialDecayFreeWindow,
            params.initialDecayRate,
            params.initialDecayFunction
        )
        Ownable(params.owner)
    {
        if (params.rewardsManager == address(0)) {
            revert RewardsManagerNotSet();
        }
        rewardsManager = IGovernanceRewardsManager(params.rewardsManager);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerToken
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

        emit VestingWalletCreated(
            beneficiary,
            newVestingWallet,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
    }

    /// @inheritdoc ISummerToken
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc ISummerToken
    function updateDecayFactor(address account) external onlyGovernor {
        _updateDecayFactor(account);
    }

    /// @inheritdoc ISummerToken
    function setGovernor(address _governor) external onlyOwner {
        address oldGovernor = address(governor);
        governor = ISummerGovernor(_governor);
        emit GovernorUpdated(oldGovernor, _governor);
    }

    /// @inheritdoc ISummerToken
    function delegateAndStake(
        address delegatee,
        uint256 amount
    ) public virtual {
        delegate(delegatee);
        _stake(amount);
    }

    /// @inheritdoc ISummerToken
    function undelegateAndUnstake(uint256 amount) external {
        delegate(address(0)); // Remove delegation
        _unstake(amount);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Delegates voting power to a specified address
     * @param delegatee The address to delegate voting power to
     */
    function delegate(address delegatee) public override {
        super.delegate(delegatee);
        _updateDecayFactor(_msgSender());
    }

    function nonces(
        address owner
    )
        public
        view
        override(IERC20Permit, ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
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

    function _stake(uint256 amount) internal {
        uint256 currentStake = rewardsManager.balanceOf(_msgSender());
        if (amount > currentStake) {
            uint256 additionalStake = amount - currentStake;
            rewardsManager.stakeFor(_msgSender(), additionalStake);
        } else if (amount < currentStake) {
            uint256 unstakeAmount = currentStake - amount;
            rewardsManager.unstakeFor(_msgSender(), unstakeAmount);
        }
    }

    function _unstake(uint256 amount) internal {
        uint256 currentStake = rewardsManager.balanceOf(_msgSender());
        uint256 unstakeAmount = amount > currentStake ? currentStake : amount;
        if (unstakeAmount > 0) {
            rewardsManager.unstakeFor(_msgSender(), unstakeAmount);
        }
    }

    function _getDelegateTo(
        address account
    ) internal view override returns (address) {
        return super.delegates(account);
    }
}
