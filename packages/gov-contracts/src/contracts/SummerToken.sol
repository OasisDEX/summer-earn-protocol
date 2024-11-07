// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {SummerVestingWallet} from "./SummerVestingWallet.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {SummerVestingWallet} from "./SummerVestingWallet.sol";
import {GovernanceRewardsManager} from "./GovernanceRewardsManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {VotingDecayManager} from "@summerfi/voting-decay/VotingDecayManager.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {IVotingDecayManager} from "@summerfi/voting-decay/IVotingDecayManager.sol";

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
    ProtocolAccessManaged,
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
    GovernanceRewardsManager public rewardsManager;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the caller's decay factor before executing the function
     * @dev Calls internal _updateDecayFactor function to recalculate the sender's current decay
     * @custom:relationship-to-votingdecay Updates voting power decay before state-changing operations
     */
    modifier updateDecay() {
        _updateDecayFactor(_msgSender());
        _;
    }

    mapping(address vestingWallet => address owner) public vestingWalletOwners;
    uint256 public immutable transferEnableDate;
    bool public transfersEnabled;
    mapping(address => bool) public whitelistedAddresses;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        TokenParams memory params
    )
        OFT(params.name, params.symbol, params.lzEndpoint, params.owner)
        ERC20Permit(params.name)
        VotingDecayManager(
            params.initialDecayFreeWindow,
            params.initialDecayRate,
            params.initialDecayFunction
        )
        ProtocolAccessManaged(params.accessManager)
        Ownable(params.owner)
    {
        rewardsManager = new GovernanceRewardsManager(
            address(this),
            params.accessManager
        );

        transferEnableDate = params.transferEnableDate;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerToken
    function setDecayRatePerSecond(
        uint256 newRatePerSecond
    ) external onlyGovernor {
        _setDecayRatePerSecond(newRatePerSecond);
    }

    /// @inheritdoc ISummerToken
    function setDecayFreeWindow(uint40 newWindow) external onlyGovernor {
        _setDecayFreeWindow(newWindow);
    }

    /// @inheritdoc ISummerToken
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external onlyGovernor {
        _setDecayFunction(newFunction);
    }

    /// @inheritdoc ISummerToken
    function enableTransfers() external onlyOwner {
        if (transfersEnabled) {
            revert TransfersAlreadyEnabled();
        }
        if (block.timestamp < transferEnableDate) {
            revert TransfersCannotBeEnabledYet();
        }
        transfersEnabled = true;
        emit TransfersEnabled();
    }

    /// @inheritdoc ISummerToken
    function addToWhitelist(address account) external onlyOwner {
        whitelistedAddresses[account] = true;
        emit AddressWhitelisted(account);
    }

    /// @inheritdoc ISummerToken
    function removeFromWhitelist(address account) external onlyOwner {
        whitelistedAddresses[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }
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
        vestingWalletOwners[newVestingWallet] = beneficiary;
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
    function updateDecayFactor(address account) external onlyDecayController {
        _updateDecayFactor(account);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Delegates voting power to a specified address
     * @param delegatee The address to delegate voting power to
     * @dev Updates the decay factor for the caller
     */
    function delegate(address delegatee) public override updateDecay {
        super.delegate(delegatee);
    }

    /**
     * @dev Required override to resolve inheritance conflict between IERC20Permit, ERC20Permit, and Nonces contracts.
     * This implementation simply calls the parent implementation and exists solely to satisfy the compiler.
     * @param owner The address to get nonces for
     * @return The current nonce for the specified owner
     */
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

    /// @inheritdoc ISummerToken
    function getVotes(
        address account
    ) public view override(ISummerToken, Votes) returns (uint256) {
        return getVotingPower(account, super.getVotes(account));
    }

    /**
     * @notice Returns the votes for an account at a specific past block, with decay factor applied
     * @param account The address to get votes for
     * @param timepoint The block number to get votes at
     * @return The historical voting power after applying the decay factor
     * @dev This function:
     * 1. Gets the historical raw votes using ERC20Votes' _getPastVotes
     * 2. Applies the current decay factor from VotingDecayManager
     * @custom:relationship-to-votingdecay
     * - Uses VotingDecayManager.getVotingPower() to apply decay
     * - Note: The decay factor is current, not historical
     * - This means voting power can decrease over time even for past checkpoints
     */
    function getPastVotes(
        address account,
        uint256 timepoint
    ) public view override returns (uint256) {
        return getVotingPower(account, super.getPastVotes(account, timepoint));
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
        if (!_canTransfer(from, to)) {
            revert TransferNotAllowed();
        }
        super._update(from, to, amount);
    }

    function _canTransfer(
        address from,
        address to
    ) internal view returns (bool) {
        // Allow minting and burning
        if (from == address(0) || to == address(0)) return true;

        // Allow transfers if globally enabled
        if (transfersEnabled) return true;

        // Allow transfers involving whitelisted addresses
        if (whitelistedAddresses[from] || whitelistedAddresses[to]) return true;

        return false;
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
     * @dev Overrides the default _getVotingUnits function to include all user tokens in voting power, including locked
     * up tokens in vesting wallets
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
     * - This function performs an additional storage read and potential balance check compared to the standard
     * implementation
     * - May slightly increase gas costs for voting-related operations
     */
    function _getVotingUnits(
        address account
    ) internal view override returns (uint256) {
        // Get raw voting units first
        uint256 directBalance = balanceOf(account);
        uint256 stakingBalance = rewardsManager.balanceOf(account);
        uint256 vestingBalance = vestingWallets[account] != address(0)
            ? balanceOf(vestingWallets[account])
            : 0;

        return directBalance + stakingBalance + vestingBalance;
    }

    /**
     * @dev Transfers, mints, or burns voting units while managing delegate votes.
     * @param from The address transferring voting units (zero address for mints)
     * @param to The address receiving voting units (zero address for burns)
     * @param amount The amount of voting units to transfer
     * @custom:internal-logic
     * - Skips vote tracking for transfers involving the rewards manager
     * - Updates total supply checkpoints for mints and burns
     * - Moves delegate votes between accounts
     * @custom:security-considerations
     * - Ensures voting power is correctly tracked when tokens move between accounts
     * - Special handling for staking/unstaking to prevent double-counting
     */
    function _transferVotingUnits(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (_handleRewardsManagerVotingTransfer(from, to, amount)) {
            return;
        }

        if (_handleVestingWalletVotingTransfer(from, to, amount)) {
            return;
        }

        super._transferVotingUnits(from, to, amount);
    }

    /**
     * @dev Handles voting power transfers involving vesting wallets
     * @param from Source address
     * @param to Destination address
     * @param amount Amount of voting units to transfer
     * @return bool True if the transfer was handled (vesting wallet case), false otherwise
     * @custom:internal-logic
     * - Checks if either from/to is a vesting wallet
     * - Handles voting power redirections for vesting wallet transfers
     */
    function _handleVestingWalletVotingTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        // Case 1: Transfer TO vesting wallet
        address vestingWalletOwner = vestingWalletOwners[to];
        if (vestingWalletOwner != address(0)) {
            // Skip if transfer is from the owner (they already have voting power)
            if (from != vestingWalletOwner) {
                // Transfer voting power to beneficiary instead of vesting wallet
                super._transferVotingUnits(from, vestingWalletOwner, amount);
            }
            return true;
        }

        // Case 2: Transfer FROM vesting wallet
        address fromVestingWalletOwner = vestingWalletOwners[from];
        if (fromVestingWalletOwner != address(0)) {
            // Skip if transfer is to the beneficiary (they already have voting power)
            if (to == fromVestingWalletOwner) {
                return true;
            }
            // Transfer voting power from beneficiary to recipient
            super._transferVotingUnits(fromVestingWalletOwner, to, amount);
            return true;
        }

        return false;
    }

    /**
     * @dev Handles voting power transfers involving the rewards manager
     * @param from Source address
     * @param to Destination address
     * @param amount Amount of voting units to transfer
     * @return bool True if the transfer was handled (rewards manager case), false otherwise
     */
    function _handleRewardsManagerVotingTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        if (from == address(rewardsManager) || to == address(rewardsManager)) {
            return true;
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the delegate address for a given account, implementing VotingDecayManager's abstract method
     * @param account The address to check delegation for
     * @return The delegate address for the account
     * @custom:relationship-to-votingdecay
     * - Required by VotingDecayManager to track delegation chains
     * - Used in decay factor calculations to follow delegation paths
     * - Supports VotingDecayManager's MAX_DELEGATION_DEPTH enforcement
     * @custom:implementation-notes
     * - Delegates are used both for voting power and decay factor inheritance
     * - Returns zero address if account has not delegated
     * - Uses OpenZeppelin's ERC20Votes delegation system via super.delegates()
     */
    function _getDelegateTo(
        address account
    ) internal view override returns (address) {
        return super.delegates(account);
    }
}
