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
    address public decayManager;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyDecayManagerOrGovernor() {
        if (decayManager != _msgSender() && !_isGovernor(_msgSender())) {
            revert CallerIsNotAuthorized(_msgSender());
        }
        _;
    }

    modifier onlyDecayManager() {
        if (decayManager != _msgSender()) {
            revert CallerIsNotDecayManager(_msgSender());
        }
        _;
    }

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
        decayManager = params.decayManager;
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
    function setDecayManager(
        address newDecayManager
    ) public onlyDecayManagerOrGovernor {
        decayManager = newDecayManager;
        emit DecayManagerUpdated(newDecayManager);
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
    function updateDecayFactor(address account) external onlyDecayManager {
        _updateDecayFactor(account);
    }

    /// @inheritdoc ISummerToken
    function delegateAndStake(address delegatee) public virtual {
        delegate(delegatee);
        _stake(balanceOf(_msgSender()));
    }

    /// @inheritdoc ISummerToken
    function undelegateAndUnstake() external {
        delegate(address(0));
        _unstake(rewardsManager.balanceOf(_msgSender()));
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
        uint256 stakingBalance = rewardsManager.balanceOf(account);

        address vestingWalletAddress = vestingWallets[account];
        uint256 vestingBalance = vestingWalletAddress != address(0)
            ? balanceOf(vestingWalletAddress)
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
        // Skip voting unit transfers for internal movements to/from the rewards manager
        if (from == address(rewardsManager) || to == address(rewardsManager)) {
            return;
        }

        super._transferVotingUnits(from, to, amount);
    }

    /**
     * @dev Stakes tokens in the rewards manager for the caller
     * @param amount The target amount to stake
     * @custom:internal-logic
     * - Compares current stake with target amount
     * - Stakes additional tokens if target is higher
     * - Unstakes excess tokens if target is lower
     * @custom:security-considerations
     * - Only modifies stake up to the available balance
     * - Ensures atomic stake/unstake operations
     */
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

    /**
     * @dev Unstakes tokens from the rewards manager for the caller
     * @param amount The amount to unstake
     * @custom:internal-logic
     * - Caps unstake amount to current staked balance
     * - Only executes if there are tokens to unstake
     * @custom:security-considerations
     * - Prevents unstaking more than staked balance
     * - Safely handles zero unstake amounts
     */
    function _unstake(uint256 amount) internal {
        uint256 currentStake = rewardsManager.balanceOf(_msgSender());
        uint256 unstakeAmount = amount > currentStake ? currentStake : amount;
        if (unstakeAmount > 0) {
            rewardsManager.unstakeFor(_msgSender(), unstakeAmount);
        }
    }

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
