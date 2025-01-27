// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {ISummerGovernor} from "../interfaces/ISummerGovernor.sol";
import {ISummerVestingWalletFactory} from "../interfaces/ISummerVestingWalletFactory.sol";
import {IGovernanceRewardsManager} from "../interfaces/IGovernanceRewardsManager.sol";
import {IOFT, SendParam, OFTReceipt, MessagingReceipt, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";

import {OFT, OFTCore} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import {GovernanceRewardsManager} from "./GovernanceRewardsManager.sol";
import {SummerVestingWalletFactory} from "./SummerVestingWalletFactory.sol";
import {DecayController} from "./DecayController.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

import {Constants} from "@summerfi/constants/Constants.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title SummerToken
 * @dev Implementation of the Summer governance token with vesting, cross-chain, and voting decay capabilities.
 * Delegation of voting power is restricted to the hub chain only.
 * @custom:security-contact security@summer.fi
 */
contract SummerToken is
    OFT,
    ERC20Burnable,
    ERC20Votes,
    ERC20Permit,
    ERC20Capped,
    ProtocolAccessManaged,
    DecayController,
    ISummerToken
{
    using VotingDecayLibrary for VotingDecayLibrary.DecayState;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the hub chain where governance actions are permitted
    uint32 public immutable hubChainId;
    address public vestingWalletFactory;
    address public rewardsManager;
    VotingDecayLibrary.DecayState internal decayState;

    uint256 public immutable transferEnableDate;
    bool public transfersEnabled;
    mapping(address account => bool isWhitelisted) public whitelistedAddresses;

    uint256 private constant SECONDS_PER_YEAR = 365.25 days;
    uint40 private constant MIN_DECAY_FREE_WINDOW = 30 days;
    uint40 private constant MAX_DECAY_FREE_WINDOW = 365.25 days;

    /// @notice Whether the contract has been initialized
    bool private _initialized;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to restrict certain functions to only be called on the hub chain.
     * This ensures that governance actions like delegation can only happen on the
     * designated hub chain.
     */
    modifier onlyHubChain() {
        if (block.chainid != hubChainId) {
            revert NotHubChain(block.chainid, hubChainId);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the Summer token with minimal required parameters
     * @param params ConstructorParams struct containing basic token configuration
     */
    constructor(
        ConstructorParams memory params
    )
        OFT(params.name, params.symbol, params.lzEndpoint, params.initialOwner)
        ERC20Permit(params.name)
        ERC20Capped(params.maxSupply)
        ProtocolAccessManaged(params.accessManager)
        DecayController(address(this))
        Ownable(params.initialOwner)
    {
        rewardsManager = address(
            new GovernanceRewardsManager(address(this), params.accessManager)
        );
        _setRewardsManager(rewardsManager);

        hubChainId = params.hubChainId;
        transferEnableDate = params.transferEnableDate;
    }

    /**
     * @dev Completes the token initialization with remaining parameters
     * @param params InitializeParams struct containing additional configuration
     */
    function initialize(InitializeParams memory params) external onlyOwner {
        if (_initialized) {
            revert AlreadyInitialized();
        }
        _validateDecayRate(params.initialYearlyDecayRate);
        _validateDecayFreeWindow(params.initialDecayFreeWindow);
        vestingWalletFactory = params.vestingWalletFactory;
        // Convert yearly rate to per-second rate
        uint256 perSecondRate = Percentage.unwrap(
            params.initialYearlyDecayRate
        ) / SECONDS_PER_YEAR;

        decayState.initialize(
            params.initialDecayFreeWindow,
            perSecondRate,
            params.initialDecayFunction
        );

        _mint(msg.sender, params.initialSupply);
        _initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Override the send function to add whitelist checks with self-transfer allowance
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        override(IOFT, OFTCore)
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        // Convert bytes32 to address using uint256 cast
        address to = address(uint160(uint256(_sendParam.to)));

        // Allow transfers if:
        // 1. Transfers are enabled globally, or
        // 2. The target address is whitelisted, or
        // 3. The sender is sending to themselves
        if (
            !transfersEnabled && !whitelistedAddresses[to] && to != msg.sender
        ) {
            revert TransferNotAllowed();
        }

        // Debit the sender's balance
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debit(
            msg.sender,
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        // Build the message and options for LayerZero
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(
            _sendParam,
            amountReceivedLD
        );

        // Send the message to the LayerZero endpoint
        msgReceipt = _lzSend(
            _sendParam.dstEid,
            message,
            options,
            _fee,
            _refundAddress
        );

        // Formulate the OFT receipt
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(
            msgReceipt.guid,
            _sendParam.dstEid,
            msg.sender,
            amountSentLD,
            amountReceivedLD
        );
    }

    /// @inheritdoc ISummerToken
    function getDecayFreeWindow() external view returns (uint40) {
        return decayState.decayFreeWindow;
    }

    /// @inheritdoc ISummerToken
    function getDecayFactor(address account) external view returns (uint256) {
        return decayState.getDecayFactor(account, _getDelegateTo);
    }

    /// @inheritdoc ISummerToken
    function getPastDecayFactor(
        address account,
        uint256 timepoint
    ) external view returns (uint256) {
        return decayState.getHistoricalDecayFactor(account, timepoint);
    }

    /// @inheritdoc ISummerToken
    function getDelegationChainLength(
        address account
    ) external view returns (uint256) {
        return decayState.getDelegationChainLength(account, _getDelegateTo);
    }

    /// @inheritdoc ISummerToken
    function getDecayRatePerYear() external view returns (Percentage) {
        // Convert per-second rate to yearly rate using simple multiplication
        // Note: We use simple multiplication rather than compound rate calculation
        // because:
        // 1. It's more intuitive for governance participants
        // 2. The decay rate is meant to be a simple linear reduction
        // 3. For typical decay rates, the difference is minimal
        uint256 yearlyRate = _getDecayRatePerSecond() * SECONDS_PER_YEAR;
        return Percentage.wrap(yearlyRate);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISummerToken
    function setDecayRatePerYear(
        Percentage newYearlyRate
    ) external onlyGovernor {
        _validateDecayRate(newYearlyRate);
        // Convert yearly rate to per-second rate
        uint256 perSecondRate = Percentage.unwrap(newYearlyRate) /
            SECONDS_PER_YEAR;
        decayState.setDecayRatePerSecond(perSecondRate);
    }

    /// @inheritdoc ISummerToken
    function setDecayFreeWindow(uint40 newWindow) external onlyGovernor {
        _validateDecayFreeWindow(newWindow);
        decayState.setDecayFreeWindow(newWindow);
    }

    /// @inheritdoc ISummerToken
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external onlyGovernor {
        decayState.setDecayFunction(newFunction);
    }

    /// @inheritdoc ISummerToken
    function updateDecayFactor(address account) external onlyDecayController {
        decayState.updateDecayFactor(account, _getDelegateTo);
    }

    /// @inheritdoc ISummerToken
    function enableTransfers() external onlyGovernor {
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
    function addToWhitelist(address account) external onlyGovernor {
        whitelistedAddresses[account] = true;
        emit AddressWhitelisted(account);
    }

    /// @inheritdoc ISummerToken
    function removeFromWhitelist(address account) external onlyGovernor {
        whitelistedAddresses[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Delegates voting power to a specified address. Can only be called on the hub chain.
     * @param delegatee The address to delegate voting power to
     * @dev Updates the decay factor for the caller
     * @custom:restriction This function can only be called on the hub chain
     */
    function delegate(
        address delegatee
    ) public override(IVotes, Votes) updateDecay(_msgSender()) onlyHubChain {
        if (delegatee == address(0)) {
            uint256 stakingBalance = IGovernanceRewardsManager(rewardsManager)
                .balanceOf(_msgSender());

            if (stakingBalance > 0) {
                revert CannotUndelegateWhileStaked();
            }
        }

        // Only initialize delegatee if they don't have decay info yet
        if (delegatee != address(0) && !decayState.hasDecayInfo(delegatee)) {
            decayState.initializeAccount(delegatee);
        }
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

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    /// @inheritdoc ISummerToken
    function getVotes(
        address account
    ) public view override(ISummerToken, Votes) returns (uint256) {
        uint256 rawVotingPower = super.getVotes(account);

        return
            decayState.getVotingPower(account, rawVotingPower, _getDelegateTo);
    }

    /// @inheritdoc ISummerToken
    function getPastVotes(
        address account,
        uint256 timepoint
    ) public view override(ISummerToken, Votes) returns (uint256) {
        uint256 pastVotingUnits = super.getPastVotes(account, timepoint);
        uint256 historicalDecayFactor = decayState.getHistoricalDecayFactor(
            account,
            timepoint
        );

        return (pastVotingUnits * historicalDecayFactor) / Constants.WAD;
    }

    /// @inheritdoc ISummerToken
    function getRawVotesAt(
        address account,
        uint256 timestamp
    ) public view returns (uint256) {
        return
            timestamp == 0
                ? super.getVotes(account)
                : super.getPastVotes(account, timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal helper to get the per-second decay rate
    /// @return The decay rate per second
    function _getDecayRatePerSecond() internal view returns (uint256) {
        return decayState.decayRatePerSecond;
    }

    /**
     * @dev Returns the delegate address for a given account, implementing VotingDecayLibrary's abstract method
     * @param account The address to check delegation for
     * @return The delegate address for the account
     * @custom:relationship-to-votingdecay
     * - Required by VotingDecayLibrary to track delegation chains
     * - Used in decay factor calculations to follow delegation paths
     * - Supports VotingDecayLibrary's MAX_DELEGATION_DEPTH enforcement
     * @custom:implementation-notes
     * - Delegates are used both for voting power and decay factor inheritance
     * - Returns zero address if account has not delegated
     * - Uses OpenZeppelin's ERC20Votes delegation system via super.delegates()
     */
    function _getDelegateTo(address account) internal view returns (address) {
        return super.delegates(account);
    }

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
    ) internal override(ERC20, ERC20Votes, ERC20Capped) {
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
        uint256 stakingBalance = IGovernanceRewardsManager(rewardsManager)
            .balanceOf(account);
        uint256 vestingBalance = ISummerVestingWalletFactory(
            vestingWalletFactory
        ).vestingWallets(account) != address(0)
            ? balanceOf(
                ISummerVestingWalletFactory(vestingWalletFactory)
                    .vestingWallets(account)
            )
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
        bool isRewardsManagerTransfer = _handleRewardsManagerVotingTransfer(
            from,
            to
        );
        bool isVestingWalletTransfer = _handleVestingWalletVotingTransfer(
            from,
            to,
            amount
        );

        if (!isRewardsManagerTransfer && !isVestingWalletTransfer) {
            super._transferVotingUnits(from, to, amount);
        }
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
        address vestingWalletOwner = ISummerVestingWalletFactory(
            vestingWalletFactory
        ).vestingWalletOwners(to);
        if (vestingWalletOwner != address(0)) {
            // Skip if transfer is from the owner (they already have voting power)
            if (from != vestingWalletOwner) {
                // Transfer voting power to beneficiary instead of vesting wallet
                super._transferVotingUnits(from, vestingWalletOwner, amount);
            }
            return true;
        }

        // Case 2: Transfer FROM vesting wallet
        address fromVestingWalletOwner = ISummerVestingWalletFactory(
            vestingWalletFactory
        ).vestingWalletOwners(from);
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
     * @return bool True if vote tracking should be skipped (rewards manager case), false if normal vote tracking should occur
     * @custom:internal-logic
     * - Returns true to skip vote tracking for two specific cases:
     *   1. When tokens come FROM the wrapped staking token (used for both unstaking and reward claims)
     *   2. When staking: transfers TO the rewards manager
     * - Returns false for all other transfers, allowing normal vote tracking
     * @custom:rationale
     * - Staking/unstaking/reward operations are handled separately by the rewards manager
     * - The wrapped staking token is used as the source for both unstaking and claiming rewards
     * - Skipping vote tracking here prevents double-counting of voting power since
     *   the rewards manager maintains its own balance tracking for staked tokens
     */
    function _handleRewardsManagerVotingTransfer(
        address from,
        address to
    ) internal view virtual returns (bool) {
        // Skip vote tracking for unstaking/rewards (from wrapped token) and staking (to rewards manager)
        if (
            from ==
            IGovernanceRewardsManager(rewardsManager).wrappedStakingToken() ||
            to == address(rewardsManager)
        ) {
            return true;
        }
        return false;
    }

    /// @dev Validates that the decay rate is between 1% and 50%
    /// @param rate The yearly decay rate to validate
    function _validateDecayRate(Percentage rate) internal pure {
        uint256 unwrappedRate = Percentage.unwrap(rate);
        if (unwrappedRate > Constants.WAD / 2) {
            revert DecayRateTooHigh(unwrappedRate);
        }
    }

    /// @dev Validates that the decay free window is between 30 days and 365.25 days
    /// @param window The window duration to validate
    function _validateDecayFreeWindow(uint40 window) internal pure {
        if (window < MIN_DECAY_FREE_WINDOW || window > MAX_DECAY_FREE_WINDOW) {
            revert InvalidDecayFreeWindow(window);
        }
    }
}
