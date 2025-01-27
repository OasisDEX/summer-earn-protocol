// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ISummerTokenErrors} from "../errors/ISummerTokenErrors.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {IGovernanceRewardsManager} from "./IGovernanceRewardsManager.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/**
 * @title ISummerToken
 * @dev Interface for the Summer governance token, combining ERC20, permit functionality,
 * and voting decay mechanisms
 */
interface ISummerToken is
    IOFT,
    IERC20,
    IERC20Permit,
    ISummerTokenErrors,
    IVotes
{
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Parameters required for contract construction
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param lzEndpoint The LayerZero endpoint address
     * @param initialOwner The initial owner of the contract
     * @param accessManager The access manager contract address
     * @param maxSupply The maximum token supply
     * @param transferEnableDate The timestamp when transfers can be enabled
     * @param hubChainId The chain ID of the hub chain
     */
    struct ConstructorParams {
        string name;
        string symbol;
        address lzEndpoint;
        address initialOwner;
        address accessManager;
        uint256 maxSupply;
        uint256 transferEnableDate;
        uint32 hubChainId;
    }

    /**
     * @dev Parameters required for contract initialization
     * @param initialSupply The initial token supply to mint
     * @param initialDecayFreeWindow The initial decay-free window duration in seconds
     * @param initialYearlyDecayRate The initial yearly decay rate as a percentage
     * @param initialDecayFunction The initial decay function type
     * @param vestingWalletFactory The address of the vesting wallet factory contract
     */
    struct InitializeParams {
        uint256 initialSupply;
        uint40 initialDecayFreeWindow;
        Percentage initialYearlyDecayRate;
        VotingDecayLibrary.DecayFunction initialDecayFunction;
        address vestingWalletFactory;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /*
     * @dev Error thrown when the chain is not the hub chain
     * @param chainId The chain ID
     * @param hubChainId The hub chain ID
     */
    error NotHubChain(uint256 chainId, uint256 hubChainId);

    /**
     * @notice Error thrown when transfers are not allowed
     */
    error TransferNotAllowed();

    /**
     * @notice Error thrown when transfers cannot be enabled yet
     */
    error TransfersCannotBeEnabledYet();

    /**
     * @notice Error thrown when transfers are already enabled
     */
    error TransfersAlreadyEnabled();

    /**
     * @notice Error thrown when the address length is invalid
     */
    error InvalidAddressLength();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when transfers are enabled
     */
    event TransfersEnabled();

    /**
     * @notice Error thrown when invalid peer arrays are provided
     */
    error SummerTokenInvalidPeerArrays();

    /**
     * @notice Emitted when an address is whitelisted
     * @param account The address of the whitelisted account
     */
    event AddressWhitelisted(address indexed account);

    /**
     * @notice Emitted when an address is removed from the whitelist
     * @param account The address of the removed account
     */
    event AddressRemovedFromWhitelist(address indexed account);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the decay free window
     * @return The decay free window in seconds
     */
    function getDecayFreeWindow() external view returns (uint40);

    /**
     * @notice Returns the yearly decay rate as a percentage
     * @return The yearly decay rate as a Percentage type
     * @dev This returns the annualized rate using simple multiplication rather than
     * compound interest calculation for clarity and predictability
     */
    function getDecayRatePerYear() external view returns (Percentage);

    /**
     * @notice Returns the decay factor for an account
     * @param account The address to get the decay factor for
     * @return The decay factor for the account
     */
    function getDecayFactor(address account) external view returns (uint256);

    /**
     * @notice Returns the decay factor for an account at a specific timepoint
     * @param account The address to get the decay factor for
     * @param timepoint The timestamp to get the decay factor at
     * @return The decay factor for the account at the specified timepoint
     */
    function getPastDecayFactor(
        address account,
        uint256 timepoint
    ) external view returns (uint256);

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
     * @notice Updates the decay factor for a specific account
     * @param account The address of the account to update
     * @dev Can only be called by the governor
     */
    function updateDecayFactor(address account) external;

    /**
     * @notice Sets the yearly decay rate for voting power decay
     * @param newYearlyRate The new decay rate per year as a Percentage
     * @dev Can only be called by the governor
     * @dev The rate is converted internally to a per-second rate using simple division
     */
    function setDecayRatePerYear(Percentage newYearlyRate) external;

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
     * @notice Enables transfers
     */
    function enableTransfers() external;

    /**
     * @notice Adds an address to the whitelist
     * @param account The address to add to the whitelist
     */
    function addToWhitelist(address account) external;

    /**
     * @notice Removes an address from the whitelist
     * @param account The address to remove from the whitelist
     */
    function removeFromWhitelist(address account) external;

    /**
     * @notice Returns the address of the rewards manager contract
     * @return The address of the rewards manager
     */
    function rewardsManager() external view returns (address);

    /**
     * @notice Gets the length of the delegation chain for an account
     * @param account The address to check delegation chain for
     * @return The length of the delegation chain (0 for self-delegated or invalid chains)
     */
    function getDelegationChainLength(
        address account
    ) external view returns (uint256);

    /**
     * @notice Returns the raw votes (before decay) for an account at a specific timepoint
     * @param account The address to get raw votes for
     * @param timestamp The timestamp to get raw votes at
     * @return The current voting power before applying any decay factor
     * @dev This returns the total voting units including direct balance, staked tokens,
     * and vesting wallet balances, but without applying the decay factor
     */
    function getRawVotesAt(
        address account,
        uint256 timestamp
    ) external view returns (uint256);

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
    ) external view returns (uint256);
}
