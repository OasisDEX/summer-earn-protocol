// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ISummerTokenErrors} from "../errors/ISummerTokenErrors.sol";
import {IVotingDecayManager} from "@summerfi/voting-decay/src/IVotingDecayManager.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";

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
     * @param governor The governor address
     * @param rewardsManager The rewards manager address
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
        address governor;
        address rewardsManager;
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

    event GovernorUpdated(
        address indexed oldGovernor,
        address indexed newGovernor
    );

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function updateDecayFactor(address account) external;

    function setGovernor(address _governor) external;

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
