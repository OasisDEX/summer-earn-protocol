// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainReceiverBase} from "../../src/base/CrossChainReceiverBase.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

contract MockFleetProxy is CrossChainReceiverBase {
    address public immutable ASSET;
    bool public receivedAssets;
    address public lastAsset;
    uint256 public lastAmount;
    bytes public lastMessage;
    uint16 public lastSourceChainId;
    bool public shouldRevert;
    bool public shouldRevertAuth;

    constructor(address _asset) {
        ASSET = _asset;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setShouldRevertAuth(bool _shouldRevertAuth) external {
        shouldRevertAuth = _shouldRevertAuth;
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN RECEIVER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mock authorization check - can be configured to revert for testing
     */
    function _requireAuthorizedCaller() internal view override {
        if (shouldRevertAuth) {
            revert Unauthorized();
        }
        // In mock, we don't enforce real authorization for testing flexibility
    }

    /**
     * @notice Returns supported operation types (only TRANSFER_ASSET for FleetProxy mock)
     */
    function _getSupportedOperationTypes()
        internal
        pure
        override
        returns (BridgeTypes.OperationType[] memory supportedTypes)
    {
        supportedTypes = new BridgeTypes.OperationType[](1);
        supportedTypes[0] = BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /**
     * @notice Handles TRANSFER_ASSET operations (asset deposits)
     */
    function _handleTransferAsset(
        BridgeTypes.RelayedTransferParams memory params
    ) internal override {
        if (shouldRevert) {
            revert("MockFleetProxy: forced revert");
        }

        receivedAssets = true;
        lastAsset = params.asset;
        lastAmount = params.amount;
        lastMessage = params.message;
        lastSourceChainId = params.sourceChainId;
    }

    function testSkipper() public {}
}
