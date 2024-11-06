// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface ISummerToken is IERC20, IERC20Permit {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TokenParams {
        string name;
        string symbol;
        address lzEndpoint;
        address governor;
        uint256 transferEnableDate;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Emitted when transfers are enabled
     */
    event TransfersEnabled();

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
