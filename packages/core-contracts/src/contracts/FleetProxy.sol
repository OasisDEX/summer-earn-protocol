// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ProtocolAccessManaged, ContractSpecificRoles} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {IFleetProxy} from "../interfaces/IFleetProxy.sol";
import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";

/**
 * @title CrossChainFleetProxy
 * @author SummerFi
 * @notice Proxy contract that receives and holds assets on a satellite chain on behalf of a source chain fleet
 * @dev Implements ICrossChainReceiver to handle cross-chain messages
 */
contract CrossChainFleetProxy is
    IFleetProxy,
    ProtocolAccessManaged,
    ReentrancyGuard,
    Pausable,
    IERC165
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The bridge router used for cross-chain communication
    IBridgeRouter public immutable bridgeRouter;

    /// @notice The bridge queue used for queuing cross-chain transfers
    IBridgeQueue public immutable bridgeQueue;

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetContract;

    /// @notice The address of the source chain's CrossChainArk
    address public sourceChainArk;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when assets are withdrawn and transferred back to source chain
    event AssetsWithdrawnAndTransferred(
        uint256 amount,
        address asset,
        uint16 sourceChainId
    );

    /// @notice Emitted when the source chain ark address is updated
    event SourceChainArkUpdated(address indexed newSourceChainArk);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetProxy
     * @param _accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _bridgeQueue Address of the bridge queue
     * @param _fleetContract Address of the Fleet contract this proxy covers
     */
    constructor(
        address _accessManager,
        address _bridgeRouter,
        address _bridgeQueue,
        address _fleetContract
    ) ProtocolAccessManaged(_accessManager) {
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_bridgeQueue == address(0)) revert InvalidBridgeQueue();
        if (_fleetContract == address(0)) revert InvalidFleetContract();

        bridgeRouter = IBridgeRouter(_bridgeRouter);
        bridgeQueue = IBridgeQueue(_bridgeQueue);
        fleetContract = _fleetContract;

        // Default zero initialization will happen automatically
        // bridgeOptions and sourceChainArk will be initialized to zeros
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetProxy
    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @inheritdoc IFleetProxy
    function totalAssets() external view returns (uint256) {
        return IFleetCommander(fleetContract).totalAssets();
    }

    /// @inheritdoc IFleetProxy
    function pause() external onlyGuardian {
        _pause();
    }

    /// @inheritdoc IFleetProxy
    function unpause() external onlyGovernor {
        _unpause();
    }

    /// @notice Updates the source chain ark address
    /// @param _sourceChainArk The new source chain ark address
    function setSourceChainArk(address _sourceChainArk) external onlyGovernor {
        if (_sourceChainArk == address(0)) revert InvalidSourceChainArk();
        sourceChainArk = _sourceChainArk;
        emit SourceChainArkUpdated(_sourceChainArk);
    }

    /// @notice Keeper function to withdraw and transfer assets
    function withdrawAndTransfer(
        uint256 amount,
        uint16 sourceChainId
    ) external payable whenNotPaused nonReentrant onlyKeeper {
        if (amount == 0) revert NoAssets();

        // 1. Get the asset from fleet config
        FleetConfig memory config = IFleetCommanderConfigProvider(fleetContract)
            .getConfig();
        address asset = address(config.bufferArk.asset());

        // 2. Withdraw from fleet contract
        IFleetCommander(fleetContract).withdraw(
            amount,
            address(this),
            address(this)
        );

        // 3. Verify we received the expected amount
        if (IERC20(asset).balanceOf(address(this)) < amount)
            revert WithdrawalFailed();

        // 4. Approve the bridge queue to transfer the assets
        IERC20(asset).approve(address(bridgeQueue), amount);

        // 5. Use BridgeQueue to queue a transfer of assets back to source chain's CrossChainArk
        bridgeQueue.queueTransferAssets(
            sourceChainId,
            asset,
            amount,
            sourceChainArk
        );

        emit AssetsWithdrawnAndTransferred(amount, asset, sourceChainId);
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-CHAIN RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainAssetReceiver
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message,
        uint16 sourceChainId
    ) external whenNotPaused nonReentrant {
        if (message.length == 0) {
            emit MessageContentNotExpected();
        }

        // Only a registered adapter can call this function
        if (!bridgeRouter.isValidAdapter(msg.sender)) {
            revert CallerNotRegisteredAdapter();
        }

        // Get the fleet config and check if the asset matches
        FleetConfig memory config = IFleetCommanderConfigProvider(fleetContract)
            .getConfig();
        if (asset != address(config.bufferArk.asset())) {
            revert InvalidAsset();
        }

        if (amount == 0) {
            revert NoAssets();
        }

        _handleReceiveAssets(asset, amount, sourceChainId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(ICrossChainAssetReceiver, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handle receiving assets from the source chain
     * @param token Address of the token
     * @param amount Amount of tokens
     * @param sourceChainId Source chain ID
     */
    function _handleReceiveAssets(
        address token,
        uint256 amount,
        uint16 sourceChainId
    ) internal {
        // Deposit the assets into the underlying fleet contract
        // First approve the fleetContract to spend the tokens
        IERC20(token).approve(fleetContract, amount);

        // Deposit assets into the fleet contract
        IFleetCommander(fleetContract).deposit(
            amount,
            address(this),
            bytes("")
        );

        // Emit event for tracking
        emit ProxyDeposit(fleetContract, token, amount, sourceChainId);
    }

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when source chain ark address is invalid
    error InvalidSourceChainArk();
    /// @notice Error thrown when bridge router address is invalid
    error InvalidBridgeRouter();
    /// @notice Error thrown when bridge queue address is invalid
    error InvalidBridgeQueue();
    /// @notice Error thrown when fleet contract address is invalid
    error InvalidFleetContract();
    /// @notice Error thrown when withdrawal failed
    error WithdrawalFailed();
}
