// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ISummerTokenErrors} from "../errors/ISummerTokenErrors.sol";
import {IVotingDecayManager} from "@summerfi/voting-decay/IVotingDecayManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";

/**
 * @title ISummerToken
 * @dev Interface for the Summer governance token, combining ERC20, permit functionality,
 * and voting decay mechanisms
 */
interface ISummerToken is
    IERC20,
    IERC20Permit,
    ISummerTokenErrors,
    IVotingDecayManager
{
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /*
     * @dev Struct for the token parameters
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param lzEndpoint The LayerZero endpoint address
     * @param owner The owner address
     * @param accessManager The access manager address
     * @param initialDecayFreeWindow The initial decay free window in seconds
     * @param initialDecayRate The initial decay rate
     * @param initialDecayFunction The initial decay function
     */
    struct TokenParams {
        string name;
        string symbol;
        address lzEndpoint;
        // Update from deployer address after deployment
        address owner;
        address accessManager;
        address decayManager;
        uint40 initialDecayFreeWindow;
        uint256 initialDecayRate;
        VotingDecayLibrary.DecayFunction initialDecayFunction;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new vesting wallet is created
     * @param beneficiary The address of the beneficiary
     * @param vestingWallet The address of the created vesting wallet
     * @param timeBasedAmount The amount of tokens to be vested based on time
     * @param goalAmounts The amounts of tokens to be vested based on goals
     * @param vestingType The type of vesting schedule
     */
    event VestingWalletCreated(
        address indexed beneficiary,
        address indexed vestingWallet,
        uint256 timeBasedAmount,
        uint256[] goalAmounts,
        SummerVestingWallet.VestingType vestingType
    );

    /**
     * @notice Emitted when the decay manager is updated
     * @param manager manager The address of the manager
     * @param isEnabled isEnabled Whether the manager is enabled
     */
    event DecayManagerUpdated(address indexed manager, bool indexed isEnabled);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current votes for an account with decay factor applied
     * @param account The address to get votes for
     * @return The current voting power after applying the decay factor
     * @dev This function:
     * 1. Gets the raw votes using ERC20Votes' _getVotes
     * 2. Applies the decay factor from VotingDecayManager
     * @custom:relationship-to-votingdecay
     * - Uses VotingDecayManager.getVotingPower() to apply decay
     * - Decay factor is determined by:
     *   - Time since last update
     *   - Delegation chain (up to MAX_DELEGATION_DEPTH)
     *   - Current decayRatePerSecond and decayFreeWindow
     */
    function getVotes(address account) external view returns (uint256);

    /**
     * @notice Creates a new vesting wallet for a beneficiary
     * @param beneficiary Address of the beneficiary to whom vested tokens are transferred
     * @param timeBasedAmount Amount of tokens to be vested based on time
     * @param goalAmounts Array of token amounts to be vested based on performance goals
     * @param vestingType Type of vesting schedule
     */
    function createVestingWallet(
        address beneficiary,
        uint256 timeBasedAmount,
        uint256[] memory goalAmounts,
        SummerVestingWallet.VestingType vestingType
    ) external;

    /**
     * @notice Mints new tokens and assigns them to the specified address
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Updates the decay factor for a specific account
     * @param account The address of the account to update
     * @dev Can only be called by the governor
     */
    function updateDecayFactor(address account) external;

    /**
     * @notice Sets the decay rate per second for voting power decay
     * @param newRatePerSecond The new decay rate per second
     * @dev Can only be called by the governor
     */
    function setDecayRatePerSecond(uint256 newRatePerSecond) external;

    /**
     * @notice Sets the decay-free window duration
     * @param newWindow The new decay-free window duration in seconds
     * @dev Can only be called by the governor
     */
    function setDecayFreeWindow(uint40 newWindow) external;

    /**
     * @notice Sets the decay function type
     * @param newFunction The new decay function to use
     * @dev Can only be called by the governor
     */
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external;

    /**
     * @notice Sets the decay manager address
     * @param manager The address of the manager
     * @param isEnabled Whether the manager is enabled
     * @dev Can only be called by the decay manager or the governor
     */
    function setDecayManager(address manager, bool isEnabled) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the vesting wallet address for a given account
     * @param owner The address of the account
     * @return The address of the vesting wallet
     */
    function vestingWallets(address owner) external view returns (address);
}
