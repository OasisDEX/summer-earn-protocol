// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {IFleetProxy} from "../interfaces/IFleetProxy.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {console} from "forge-std/console.sol";
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

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetContract;

    /// @notice The gas limit for bridge operations
    uint64 public immutable bridgeGasLimit;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainArkProxy
     * @param _accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _fleetContract Address of the Fleet contract this proxy covers
     * @param _bridgeGasLimit The gas limit for bridge operations
     */
    constructor(
        address _accessManager,
        address _bridgeRouter,
        address _fleetContract,
        uint64 _bridgeGasLimit
    ) ProtocolAccessManaged(_accessManager) {
        bridgeRouter = IBridgeRouter(_bridgeRouter);
        fleetContract = _fleetContract;
        bridgeGasLimit = _bridgeGasLimit;
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
        return _balanceOfAsset();
    }

    /// @inheritdoc IFleetProxy
    function pause() external onlyGuardian {
        _pause();
    }

    /// @inheritdoc IFleetProxy
    function unpause() external onlyGovernor {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-CHAIN RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // TODO: Need to consider what happens when received messages revert...
    /// @inheritdoc ICrossChainReceiver
    function receiveMessage(
        uint16 sourceChainId,
        bytes calldata message
    ) external whenNotPaused nonReentrant {
        // Only a registered adapter can call this function
        if (!bridgeRouter.isValidAdapter(msg.sender)) {
            revert CallerNotRegisteredAdapter();
        }

        // Since this is a proxy focused on withdrawals,
        // we can simply interpret any message as a withdrawal request
        (address token, uint256 amount, address recipient) = abi.decode(
            message,
            (address, uint256, address)
        );

        _handleWithdrawAssets(token, amount, recipient, sourceChainId);
    }

    /// @inheritdoc ICrossChainReceiver
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message
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

        _handleReceiveAssets(asset, amount);
    }

    /// @inheritdoc ICrossChainReceiver
    function receiveStateRead(
        bytes calldata,
        address,
        uint16,
        bytes32
    ) external view whenNotPaused {
        // FleetProxy is not configured to receive the results of state reads from other chains
        revert InvalidOperation();
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(ICrossChainReceiver, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handle receiving assets from the source chain
     * @param token Address of the token
     * @param amount Amount of tokens
     */
    function _handleReceiveAssets(address token, uint256 amount) internal {
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
        emit ProxyDeposit(fleetContract, token, amount);
    }

    /**
     * @notice Handle withdrawing assets back to the source chain
     * @param token Address of the token
     * @param amount Amount of tokens
     * @param recipient Address to receive the tokens on the source chain
     * @param sourceChainId ID of the source chain
     */
    function _handleWithdrawAssets(
        address token,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) internal {
        // 1. First, withdraw the assets from the fleet contract
        // The fleetContract should implement the IFleetCommander interface with a withdraw function
        IFleetCommander(fleetContract).withdraw(
            amount,
            address(this), // Proxy receives the assets
            address(this) // Proxy is the owner of the shares
        );

        // 2. Bridge the tokens back to the source chain
        // First approve the router to spend the tokens
        IERC20(token).approve(address(bridgeRouter), amount);

        try
            bridgeRouter.transferAssets{value: msg.value}(
                sourceChainId,
                token,
                amount,
                recipient,
                _getBridgeOptions()
            )
        returns (bytes32 operationId) {
            // Emit event for tracking
            emit ProxyWithdrawal(recipient, token, amount, operationId);
        } catch {
            // If the bridge operation fails, revert
            revert BridgeOperationFailed();
        }
    }

    /**
     * @notice Get default bridge options
     * @return Default bridge options struct
     */
    function _getBridgeOptions()
        internal
        view
        returns (BridgeTypes.BridgeOptions memory)
    {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(0),
                adapterParams: BridgeTypes.AdapterParams({
                    gasLimit: bridgeGasLimit,
                    msgValue: 0,
                    calldataSize: 0,
                    options: ""
                })
            });
    }

    /**
     * @notice Internal function to get the balance of the main asset
     * @return The balance of the main asset
     */
    function _balanceOfAsset() internal view returns (uint256) {
        // Get the asset from the fleet config
        FleetConfig memory config = IFleetCommanderConfigProvider(fleetContract)
            .getConfig();
        address asset = address(config.bufferArk.asset());

        // Return the actual token balance
        return IERC20(asset).balanceOf(address(this));
    }
}
