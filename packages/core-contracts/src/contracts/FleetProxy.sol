// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ProtocolAccessManagedExt, ContractSpecificRoles} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedExt.sol";
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
    ProtocolAccessManagedExt,
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

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetContract;

    /// @notice The bridge options for cross-chain transfers
    BridgeTypes.BridgeOptions public bridgeOptions;

    /// @notice The address of the source chain's CrossChainArk
    address public immutable sourceChainArk;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when assets are withdrawn and transferred back to source chain
    event AssetsWithdrawnAndTransferred(
        uint256 amount,
        address asset,
        uint16 sourceChainId
    );

    /// @notice Emitted when bridge options are updated
    event BridgeOptionsUpdated(BridgeTypes.BridgeOptions bridgeOptions);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetProxy
     * @param _accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _fleetContract Address of the Fleet contract this proxy covers
     * @param _bridgeOptions The bridge options for cross-chain transfers
     * @param _sourceChainArk Address of the source chain's CrossChainArk
     */
    constructor(
        address _accessManager,
        address _bridgeRouter,
        address _fleetContract,
        BridgeTypes.BridgeOptions memory _bridgeOptions,
        address _sourceChainArk
    ) ProtocolAccessManagedExt(_accessManager) {
        if (_sourceChainArk == address(0)) revert InvalidSourceChainArk();

        bridgeRouter = IBridgeRouter(_bridgeRouter);
        fleetContract = _fleetContract;
        bridgeOptions = _bridgeOptions;
        sourceChainArk = _sourceChainArk;
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

    /// @notice Updates the bridge options
    /// @param _bridgeOptions The new bridge options
    function setBridgeOptions(
        BridgeTypes.BridgeOptions memory _bridgeOptions
    ) external onlyGovernorOrKeeper {
        bridgeOptions = _bridgeOptions;
        emit BridgeOptionsUpdated(_bridgeOptions);
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
                        NEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Keeper function to withdraw and transfer assets
    function withdrawAndTransfer(
        uint256 amount,
        uint16 sourceChainId
    ) external payable whenNotPaused nonReentrant onlyKeeper {
        // 1. Withdraw from fleet contract
        IFleetCommander(fleetContract).withdraw(
            amount,
            address(this),
            address(this)
        );

        // 2. Get the asset from fleet config
        FleetConfig memory config = IFleetCommanderConfigProvider(fleetContract)
            .getConfig();
        address asset = address(config.bufferArk.asset());

        // 3. Use BridgeRouter to transfer assets back to source chain's CrossChainArk
        bridgeRouter.executeTransferAssets{value: msg.value}(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: sourceChainId,
                asset: asset,
                amount: amount,
                recipient: sourceChainArk,
                options: bridgeOptions
            })
        );

        emit AssetsWithdrawnAndTransferred(amount, asset, sourceChainId);
    }

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when source chain ark address is invalid
    error InvalidSourceChainArk();

    /// @notice Error thrown when attempting to withdraw via message
    error WithdrawalViaMessageNotSupported();

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
}
