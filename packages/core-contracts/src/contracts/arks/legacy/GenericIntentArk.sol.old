// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ark} from "../Ark.sol";
import {IIntentHandler} from "../../interfaces/IIntentHandler.sol";
import {IIntentBondFactory} from "../../interfaces/IIntentBondFactory.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ArkParams} from "../../types/ArkTypes.sol";

/**
 * @title GenericIntentArk
 * @notice Generic Ark that can handle intents and work with protocol adapters
 * @dev This Ark posts intents offchain and can only cancel them before they're solved
 */
contract GenericIntentArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The intent handler contract
    IIntentHandler public immutable intentHandler;

    /// @notice The intent bond factory contract
    IIntentBondFactory public immutable intentBondFactory;

    /// @notice Mapping of intent IDs to their status
    mapping(bytes32 => bool) public activeIntents;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        ArkParams memory _params,
        address _intentHandler,
        address _intentBondFactory
    ) Ark(_params) {
        intentHandler = IIntentHandler(_intentHandler);
        intentBondFactory = IIntentBondFactory(_intentBondFactory);
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Post an intent (offchain action - this just records it)
     * @param intentId Unique identifier for the intent
     * @param requiredNotional Required notional value for the intent
     * @param term Term length in seconds
     * @param targetYield Target yield amount
     * @param oracle Address of oracle for price verification
     * @param expiry Expiry timestamp
     */
    function postIntent(
        bytes32 intentId,
        uint256 requiredNotional,
        uint256 term,
        uint256 targetYield,
        address oracle,
        uint256 expiry
    ) external onlyKeeper {
        if (activeIntents[intentId]) revert IntentArk__IntentAlreadyExists();
        if (expiry <= block.timestamp) revert IntentArk__IntentExpired();

        // Record the intent as active
        activeIntents[intentId] = true;
        IERC20(config.asset).forceApprove(
            address(intentHandler),
            requiredNotional
        );

        // Create intent in the handler
        intentHandler.createIntent(
            address(this),
            requiredNotional,
            term,
            targetYield,
            address(config.asset),
            oracle,
            expiry
        );

        emit IntentPosted(intentId, address(0), requiredNotional);
    }

    /**
     * @notice Cancel an intent before it's solved
     * @param intentId Unique identifier for the intent
     */
    function cancelIntent(bytes32 intentId) external onlyKeeper {
        if (!activeIntents[intentId]) revert IntentArk__IntentNotFound();

        // Mark intent as cancelled
        activeIntents[intentId] = false;
        IERC20(config.asset).forceApprove(address(intentHandler), 0);

        // Resign the intent in the handler
        intentHandler.resignByUser(address(this));

        emit IntentCancelled(intentId);
    }

    /**
     * @notice Check if an intent is active
     * @param intentId Unique identifier for the intent
     * @return True if intent is active, false otherwise
     */
    function isIntentActive(bytes32 intentId) external view returns (bool) {
        return activeIntents[intentId];
    }

    /**
     * @notice Get intent details from the handler
     * @param intentId Unique identifier for the intent
     * @return Intent struct from handler
     */
    function getIntent(
        bytes32 intentId
    ) external view returns (IIntentHandler.Intent memory) {
        if (!activeIntents[intentId]) revert IntentArk__IntentNotFound();
        return intentHandler.getIntent(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override _board to handle basic asset supply
     * @param amount Amount of assets to board
     * @param data Additional data (unused in generic ark)
     */
    function _board(uint256 amount, bytes calldata data) internal override {
        // Generic Ark doesn't handle specific protocol interactions
        // This is just for basic asset management
        // Protocol-specific actions are handled by adapters
    }

    /**
     * @notice Override _disembark to handle basic asset withdrawal
     * @param amount Amount of assets to disembark
     * @param data Additional data (unused in generic ark)
     */
    function _disembark(uint256 amount, bytes calldata data) internal override {
        // Generic Ark doesn't handle specific protocol interactions
        // This is just for basic asset management
        // Protocol-specific actions are handled by adapters
    }

    /**
     * @notice Override _harvest to handle basic reward collection
     * @return rewardTokens Array of reward token addresses
     * @return rewardAmounts Array of reward amounts
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // Generic Ark doesn't handle specific protocol interactions
        // This is just for basic asset management
        // Protocol-specific actions are handled by adapters
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /**
     * @notice Override _validateBoardData to allow any data
     * @param data Data to validate (always valid in generic ark)
     */
    function _validateBoardData(bytes calldata data) internal override {
        // Generic Ark accepts any board data
        // Protocol-specific validation is handled by adapters
    }

    /**
     * @notice Override _validateDisembarkData to allow any data
     * @param data Data to validate (always valid in generic ark)
     */
    function _validateDisembarkData(bytes calldata data) internal override {
        // Generic Ark accepts any disembark data
        // Protocol-specific validation is handled by adapters
    }

    /**
     * @notice Override _withdrawableTotalAssets to return basic balance
     * @return Total withdrawable assets
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        // Generic Ark just returns the asset balance
        return IERC20(config.asset).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    event IntentPosted(
        bytes32 indexed intentId,
        address indexed solver,
        uint256 requiredNotional
    );
    event IntentCancelled(bytes32 indexed intentId);
    event IntentSolved(
        bytes32 indexed intentId,
        address indexed solver,
        address indexed adapter
    );

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error IntentArk__IntentAlreadyExists();
    error IntentArk__IntentNotFound();
    error IntentArk__IntentExpired();
}
