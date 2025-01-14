// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";
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

    /*
     * @dev Struct for the token parameters
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param lzEndpoint The LayerZero endpoint address
     * @param initialOwner The owner address
     * @param accessManager The access manager address
     * @param initialDecayFreeWindow The initial decay free window in seconds
     * @param initialDecayRate The initial decay rate
     * @param initialDecayFunction The initial decay function
     * @param governor The governor address
     * @param transferEnableDate The transfer enable date
     * @param maxSupply The maximum supply of the token
     * @param initialSupply The initial supply of the token
     * @param hubChainId The chain ID of the hub chain
     * @param peerEndpointIds Array of chain IDs for peers
     * @param peerAddresses Array of peer addresses corresponding to chainIds
     */
    struct TokenParams {
        string name;
        string symbol;
        address lzEndpoint;
        // Update from deployer address after deployment
        address initialOwner;
        address accessManager;
        uint40 initialDecayFreeWindow;
        Percentage initialYearlyDecayRate;
        VotingDecayLibrary.DecayFunction initialDecayFunction;
        uint256 transferEnableDate;
        uint256 maxSupply;
        uint256 initialSupply;
        uint32 hubChainId;
        uint32[] peerEndpointIds; // Array of chain IDs for peers
        address[] peerAddresses; // Array of peer addresses corresponding to chainIds
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
    function rewardsManager() external view returns (IGovernanceRewardsManager);

    /**
     * @notice Gets the length of the delegation chain for an account
     * @param account The address to check delegation chain for
     * @return The length of the delegation chain (0 for self-delegated or invalid chains)
     */
    function getDelegationChainLength(
        address account
    ) external view returns (uint256);
}
