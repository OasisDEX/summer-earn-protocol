// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title CrossChainArkProxy
 * @author SummerFi
 * @notice Proxy contract that receives and holds assets on a satellite chain on behalf of a source chain fleet
 * @dev Implements ICrossChainReceiver to handle cross-chain messages
 */
contract CrossChainArkProxy is
    ICrossChainReceiver,
    ArkAccessManaged,
    ReentrancyGuard,
    Pausable,
    IERC165
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when assets are received from the source chain
     * @param token Address of the token received
     * @param amount Amount of tokens received
     * @param sourceChainId ID of the source chain
     * @param messageId Unique ID of the transfer message
     */
    event AssetsReceived(
        address indexed token,
        uint256 amount,
        uint16 indexed sourceChainId,
        bytes32 indexed messageId
    );

    /**
     * @notice Emitted when assets are sent back to the source chain
     * @param token Address of the token sent
     * @param amount Amount of tokens sent
     * @param sourceChainId ID of the destination (source) chain
     * @param messageId Unique ID of the transfer message
     */
    event AssetsSent(
        address indexed token,
        uint256 amount,
        uint16 indexed sourceChainId,
        bytes32 indexed messageId
    );

    /**
     * @notice Emitted when a new authorized source chain is registered
     * @param sourceChainId ID of the source chain
     * @param sourceAddress Address of the authorized contract on the source chain
     */
    event SourceChainRegistered(
        uint16 indexed sourceChainId,
        address indexed sourceAddress
    );

    /**
     * @notice Emitted when an authorized source chain is removed
     * @param sourceChainId ID of the source chain
     * @param sourceAddress Address of the previously authorized contract
     */
    event SourceChainRemoved(
        uint16 indexed sourceChainId,
        address indexed sourceAddress
    );

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a message is received from an unauthorized source chain
    error UnauthorizedSourceChain(uint16 sourceChainId, address sourceAddress);

    /// @notice Thrown when trying to send tokens that exceed available balance
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Thrown when an operation on an unsupported token is attempted
    error UnsupportedToken(address token);

    /// @notice Thrown when the bridge operation fails
    error BridgeOperationFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The bridge router used for cross-chain communication
    IBridgeRouter public immutable bridgeRouter;

    /// @notice Mapping of supported token addresses
    mapping(address => bool) public supportedTokens;

    /// @notice Mapping of source chain IDs to authorized addresses on that chain
    mapping(uint16 => mapping(address => bool)) public authorizedSources;

    /// @notice Mapping of token addresses to their current balance held by this proxy
    mapping(address => uint256) public tokenBalances;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainArkProxy
     * @param _accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _supportedTokens Array of supported token addresses
     * @param _sourceChainIds Array of authorized source chain IDs
     * @param _sourceAddresses Array of authorized addresses on source chains (must match _sourceChainIds length)
     */
    constructor(
        address _accessManager,
        address _bridgeRouter,
        address[] memory _supportedTokens,
        uint16[] memory _sourceChainIds,
        address[] memory _sourceAddresses
    ) ArkAccessManaged(_accessManager) {
        if (_sourceChainIds.length != _sourceAddresses.length) {
            revert(
                "CrossChainArkProxy: Chain IDs and addresses length mismatch"
            );
        }

        bridgeRouter = IBridgeRouter(_bridgeRouter);

        // Register supported tokens
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens[_supportedTokens[i]] = true;
        }

        // Register authorized source chains
        for (uint256 i = 0; i < _sourceChainIds.length; i++) {
            authorizedSources[_sourceChainIds[i]][_sourceAddresses[i]] = true;
            emit SourceChainRegistered(_sourceChainIds[i], _sourceAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current balance of a token held by this proxy
     * @param token Address of the token
     * @return Balance of the specified token
     */
    function getBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    /**
     * @notice Pause the contract functionality
     * @dev Can only be called by authorized administrators
     */
    function pause() external onlyGuardian {
        _pause();
    }

    /**
     * @notice Unpause the contract functionality
     * @dev Can only be called by authorized administrators
     */
    function unpause() external onlyGovernor {
        _unpause();
    }

    /**
     * @notice Add a supported token
     * @param token Address of the token to add
     * @dev Can only be called by authorized administrators
     */
    function addSupportedToken(address token) external onlyGuardian {
        supportedTokens[token] = true;
    }

    /**
     * @notice Remove a supported token
     * @param token Address of the token to remove
     * @dev Can only be called by authorized administrators
     */
    function removeSupportedToken(address token) external onlyGuardian {
        supportedTokens[token] = false;
    }

    /**
     * @notice Register an authorized source chain
     * @param sourceChainId ID of the source chain
     * @param sourceAddress Address of the authorized contract on the source chain
     * @dev Can only be called by authorized administrators
     */
    function registerSourceChain(
        uint16 sourceChainId,
        address sourceAddress
    ) external onlyGuardian {
        authorizedSources[sourceChainId][sourceAddress] = true;
        emit SourceChainRegistered(sourceChainId, sourceAddress);
    }

    /**
     * @notice Remove an authorized source chain
     * @param sourceChainId ID of the source chain
     * @param sourceAddress Address of the contract on the source chain
     * @dev Can only be called by authorized administrators
     */
    function removeSourceChain(
        uint16 sourceChainId,
        address sourceAddress
    ) external onlyGuardian {
        authorizedSources[sourceChainId][sourceAddress] = false;
        emit SourceChainRemoved(sourceChainId, sourceAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-CHAIN RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainReceiver
    function receiveMessage(
        bytes calldata message,
        address recipient,
        uint16 sourceChainId,
        bytes32 messageId
    ) external override whenNotPaused nonReentrant {
        // Only the bridge router can call this function
        if (msg.sender != address(bridgeRouter)) {
            revert("CrossChainArkProxy: Caller is not the bridge router");
        }

        // Check if the source chain and address are authorized
        if (!authorizedSources[sourceChainId][recipient]) {
            revert UnauthorizedSourceChain(sourceChainId, recipient);
        }

        // Parse the message
        // Message format: function selector + parameters
        bytes4 selector = abi.decode(message[:4], (bytes4));

        // Route to the appropriate function based on the selector
        if (selector == this.receiveAssets.selector) {
            (address token, uint256 amount) = abi.decode(
                message[4:],
                (address, uint256)
            );
            _handleReceiveAssets(token, amount, sourceChainId, messageId);
        } else if (selector == this.withdrawAssets.selector) {
            (address token, uint256 amount, address recip) = abi.decode(
                message[4:],
                (address, uint256, address)
            );
            _handleWithdrawAssets(
                token,
                amount,
                recip,
                sourceChainId,
                messageId
            );
        } else {
            revert("CrossChainArkProxy: Unknown function selector");
        }
    }

    /// @inheritdoc ICrossChainReceiver
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external override whenNotPaused {
        // Only the bridge router can call this function
        if (msg.sender != address(bridgeRouter)) {
            revert("CrossChainArkProxy: Caller is not the bridge router");
        }

        // Check if the source chain and address are authorized
        if (!authorizedSources[sourceChainId][requestor]) {
            revert UnauthorizedSourceChain(sourceChainId, requestor);
        }

        // Process the state read result
        // This function is typically used to return the token balance to the source chain
        // The implementation depends on the specific use case
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external view override(ICrossChainReceiver, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @notice Function signature for receiving assets from source chain
     * @dev This function is not meant to be called directly, but through receiveMessage
     * @param token Address of the token
     * @param amount Amount of tokens
     */
    function receiveAssets(address token, uint256 amount) external view {
        // This function exists only to generate the function selector
        // The actual logic is in _handleReceiveAssets
        revert("CrossChainArkProxy: Do not call directly");
    }

    /**
     * @notice Function signature for withdrawing assets back to source chain
     * @dev This function is not meant to be called directly, but through receiveMessage
     * @param token Address of the token
     * @param amount Amount of tokens
     * @param recipient Address to receive the tokens on the source chain
     */
    function withdrawAssets(
        address token,
        uint256 amount,
        address recipient
    ) external view {
        // This function exists only to generate the function selector
        // The actual logic is in _handleWithdrawAssets
        revert("CrossChainArkProxy: Do not call directly");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handle receiving assets from the source chain
     * @param token Address of the token
     * @param amount Amount of tokens
     * @param sourceChainId ID of the source chain
     * @param messageId Unique ID of the message
     */
    function _handleReceiveAssets(
        address token,
        uint256 amount,
        uint16 sourceChainId,
        bytes32 messageId
    ) internal {
        if (!supportedTokens[token]) {
            revert UnsupportedToken(token);
        }

        // Update the token balance
        tokenBalances[token] += amount;

        // Emit event for tracking
        emit AssetsReceived(token, amount, sourceChainId, messageId);

        // Send a confirmation message back to the source chain
        _sendConfirmation(sourceChainId, messageId);
    }

    /**
     * @notice Handle withdrawing assets back to the source chain
     * @param token Address of the token
     * @param amount Amount of tokens
     * @param recipient Address to receive the tokens on the source chain
     * @param sourceChainId ID of the source chain
     * @param messageId Unique ID of the message
     */
    function _handleWithdrawAssets(
        address token,
        uint256 amount,
        address recipient,
        uint16 sourceChainId,
        bytes32 messageId
    ) internal {
        if (!supportedTokens[token]) {
            revert UnsupportedToken(token);
        }

        // Check if we have enough balance
        if (tokenBalances[token] < amount) {
            revert InsufficientBalance(amount, tokenBalances[token]);
        }

        // Update the token balance
        tokenBalances[token] -= amount;

        // Bridge the tokens back to the source chain
        IERC20(token).approve(address(bridgeRouter), amount);

        try
            bridgeRouter.transferAssets{value: msg.value}(
                sourceChainId,
                token,
                amount,
                recipient,
                _getDefaultBridgeOptions()
            )
        returns (bytes32 transferId) {
            // Emit event for tracking
            emit AssetsSent(token, amount, sourceChainId, transferId);

            // Send a confirmation message back to the source chain
            _sendConfirmation(sourceChainId, messageId);
        } catch {
            // If the bridge operation fails, restore the token balance
            tokenBalances[token] += amount;
            revert BridgeOperationFailed();
        }
    }

    /**
     * @notice Send a confirmation message back to the source chain
     * @param sourceChainId ID of the source chain
     * @param messageId ID of the message being confirmed
     */
    function _sendConfirmation(
        uint16 sourceChainId,
        bytes32 messageId
    ) internal {
        // Encode the confirmation message
        bytes memory confirmationMessage = abi.encode(messageId);

        // Send the confirmation back to the source chain
        // The exact destination address can be determined from authorizedSources mapping
        address sourceAddress;

        // Find the first authorized source address for this chain
        // In production, this would be more sophisticated
        for (
            address addr = address(1);
            addr != address(0);
            addr = address(uint160(addr) + 1)
        ) {
            if (authorizedSources[sourceChainId][addr]) {
                sourceAddress = addr;
                break;
            }
        }

        if (sourceAddress != address(0)) {
            bridgeRouter.sendMessage{value: 0}(
                sourceChainId,
                sourceAddress,
                confirmationMessage,
                _getDefaultBridgeOptions()
            );
        }
    }

    /**
     * @notice Get default bridge options
     * @return Default bridge options struct
     */
    function _getDefaultBridgeOptions()
        internal
        pure
        returns (BridgeTypes.BridgeOptions memory)
    {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(0),
                adapterParams: BridgeTypes.AdapterParams({
                    gasLimit: 100, // TODO: set a reasonable default
                    msgValue: 0,
                    calldataSize: 0,
                    options: ""
                })
            });
    }
}
