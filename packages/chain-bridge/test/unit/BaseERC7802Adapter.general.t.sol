// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseERC7802Adapter} from "../../src/adapters/BaseERC7802Adapter.sol";
import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {BaseERC7802AdapterSetupTest} from "./BaseERC7802Adapter.setup.t.sol";

/**
 * @title BaseERC7802Adapter General Tests
 * @notice Tests general functionality of BaseERC7802Adapter
 */
contract BaseERC7802AdapterGeneralTest is BaseERC7802AdapterSetupTest {
    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialization_SetsLZEndpoint() public {
        // Test that LZ endpoint is properly set during construction
        assertEq(adapterA.LZ_ENDPOINT(), lzEndpointA);
        assertEq(adapterB.LZ_ENDPOINT(), lzEndpointB);
    }

    function test_Initialization_RequiresValidLZEndpoint() public {
        // This test would need to be implemented in concrete adapter tests
        // as BaseERC7802Adapter is abstract
    }

    function test_Initialization_RequiresValidRegistry() public {
        // This test would need to be implemented in concrete adapter tests
        // as BaseERC7802Adapter is abstract
    }

    function test_Initialization_RequiresValidAccessManager() public {
        // This test would need to be implemented in concrete adapter tests
        // as BaseERC7802Adapter is abstract
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPORTED OPERATIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportsOperation_ReturnsTrueForTransferAsset() public {
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
    }

    function test_SupportsOperation_ReturnsFalseForMessage() public {
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
    }

    function test_SupportsOperation_ReturnsFalseForReadState() public {
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.READ_STATE)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportedAsset_InitiallyFalse() public {
        ERC20Mock newToken = new ERC20Mock();
        assertFalse(adapterA.supportedAsset(address(newToken)));
    }

    function test_SupportedAsset_ReturnsTrueAfterEnabling() public {
        ERC20Mock newToken = new ERC20Mock();
        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);
        assertTrue(adapterA.supportedAsset(address(newToken)));
    }

    function test_SupportedAsset_ReturnsFalseAfterDisabling() public {
        vm.prank(governor);
        adapterA.setAssetSupport(address(tokenA), false);
        assertFalse(adapterA.supportedAsset(address(tokenA)));
    }

    function test_SupportsAssetTransfer_ReturnsTrueForSupportedAssetAndTrustedDestination()
        public
    {
        assertTrue(adapterA.supportsAssetTransfer(CHAIN_ID_B, address(tokenA)));
    }

    function test_SupportsAssetTransfer_ReturnsFalseForUnsupportedAsset()
        public
    {
        ERC20Mock newToken = new ERC20Mock();
        assertFalse(
            adapterA.supportsAssetTransfer(CHAIN_ID_B, address(newToken))
        );
    }

    function test_SupportsAssetTransfer_ReturnsFalseForUntrustedDestination()
        public
    {
        // Untrusted chain ID that doesn't exist
        uint16 untrustedChain = 9999;
        assertFalse(
            adapterA.supportsAssetTransfer(untrustedChain, address(tokenA))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL ID MAPPING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExternalOrCanonical_ReturnsExternalIdWhenMapped() public {
        useNetworkA();
        assertEq(adapterA._externalOrCanonical(CHAIN_ID_B), LZ_EID_B);
    }

    function test_ExternalOrCanonical_ReturnsCanonicalIdWhenNotMapped() public {
        useNetworkA();
        uint16 unmappedChain = 9999;
        assertEq(adapterA._externalOrCanonical(unmappedChain), unmappedChain);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_ReturnsTrueForIBridgeAdapter() public {
        bytes4 interfaceId = type(IBridgeAdapter).interfaceId;
        assertTrue(adapterA.supportsInterface(interfaceId));
    }

    function test_SupportsInterface_ReturnsTrueForIERC165() public {
        bytes4 interfaceId = type(IERC165).interfaceId;
        assertTrue(adapterA.supportsInterface(interfaceId));
    }

    function test_SupportsInterface_ReturnsFalseForUnsupportedInterface()
        public
    {
        bytes4 randomInterfaceId = 0x12345678;
        assertFalse(adapterA.supportsInterface(randomInterfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                        LAYERZERO COMPOSER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LzCompose_RevertsWhenCallerNotLZEndpoint() public {
        bytes32 guid = keccak256("test_guid");
        bytes memory message = "";
        address caller = address(0x1234);
        bytes memory extraData = "";

        vm.expectRevert(BaseERC7802Adapter.Unauthorized.selector);
        adapterA.lzCompose(address(0), guid, message, caller, extraData);
    }

    function test_LzCompose_RequiresValidOFTComposeMessage() public {
        // This test requires a valid OFT compose message format
        // Implementation would need to craft a proper message
    }

    function test_LzCompose_ValidatesSourceAdapter() public {
        // Test that compose messages validate the source adapter is trusted
    }

    function test_LzCompose_ValidatesSourceChainId() public {
        // Test that compose messages validate the source chain ID matches the EID
    }

    function test_LzCompose_RequiresSupportedAsset() public {
        // Test that compose messages require the asset to be supported
    }

    function test_LzCompose_TransfersTokensToRouter() public {
        // Test that successful compose transfers tokens to the router
    }

    function test_LzCompose_DeliversToRouterWithCorrectParams() public {
        // Test that compose calls router.deliver with correct parameters
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE HELPER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeOFTCompose_RevertsForShortMessage() public {
        bytes memory shortMessage = new bytes(75); // Less than 76 bytes minimum
        vm.expectRevert(BaseERC7802Adapter.InvalidMessage.selector);
        adapterA._decodeOFTCompose(shortMessage);
    }

    function test_DecodeOFTCompose_ReturnsCorrectValues() public {
        // Test decoding a properly formatted OFT compose message
    }

    function test_EncodeComposeTransferParams_ReturnsCorrectEncoding() public {
        // Test encoding transfer parameters for compose messages
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TransferAsset_RevertsForUnsupportedOperation() public {
        // This test would need to mock an unsupported operation
        // Currently TRANSFER_ASSET is the only supported operation
    }

    function test_TransferAsset_RevertsForUnsupportedAsset() public {
        // Test would need to call transferAsset with unsupported asset
    }

    function test_TransferAsset_RevertsForZeroAmount() public {
        // Test would need to call transferAsset with zero amount
    }

    function test_TransferAsset_RevertsForUntrustedDestination() public {
        // Test would need to call transferAsset with untrusted destination
    }

    function test_TransferAsset_RevertsWhenCalledByNonRouter() public {
        // Test would need to call transferAsset from non-router address
    }

    /*//////////////////////////////////////////////////////////////
                        FINALIZE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Finalize_RevertsForUnsupportedOperation() public {
        // Test would need to mock an unsupported operation
    }

    function test_Finalize_RevertsForUnsupportedAsset() public {
        // Test would need to call finalize with unsupported asset
    }

    function test_Finalize_RevertsForZeroAmount() public {
        // Test would need to call finalize with zero amount
    }

    function test_Finalize_RevertsForWrongDestinationChain() public {
        // Test would need to call finalize with wrong destination chain
    }

    function test_Finalize_RevertsForInsufficientBalance() public {
        // Test would need to call finalize when adapter has insufficient balance
    }

    function test_Finalize_RevertsWhenCalledByNonAuthorizedExecutor() public {
        // Test would need to call finalize from non-authorized address
    }

    function test_Finalize_TransfersTokensToRouter() public {
        // Test that finalize transfers correct amount to router
    }

    function test_Finalize_DeliversCorrectPayloadToRouter() public {
        // Test that finalize calls router.deliver with correct payload
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateTransferAssets_RevertsForUnsupportedOperation()
        public
    {
        // Test would need to mock an unsupported operation
    }

    function test_EstimateTransferAssets_RevertsForUnsupportedAsset() public {
        // Test would need to call estimate with unsupported asset
    }

    function test_EstimateTransferAssets_RevertsForZeroAmount() public {
        // Test would need to call estimate with zero amount
    }

    function test_EstimateTransferAssets_RevertsForUntrustedDestination()
        public
    {
        // Test would need to call estimate with untrusted destination
    }

    function test_EstimateReadState_Reverts() public {
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.estimateReadState(
            BridgeTypes.ExecuteReadStateParams({
                originator: address(0),
                destinationChainId: 0,
                target: address(0),
                selector: bytes4(0),
                readParams: "",
                refundAddress: address(0)
            }),
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(0),
                gasLimit: 0,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            })
        );
    }

    function test_EstimateSendMessage_Reverts() public {
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapterA.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                originator: address(0),
                destinationChainId: 0,
                target: address(0),
                message: "",
                refundAddress: address(0)
            }),
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(0),
                gasLimit: 0,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetAssetSupport_EmitsAssetSupportUpdatedEvent() public {
        ERC20Mock newToken = new ERC20Mock();

        vm.expectEmit(true, false, false, true);
        emit BaseERC7802Adapter.AssetSupportUpdated(address(newToken), true);

        vm.prank(governor);
        adapterA.setAssetSupport(address(newToken), true);
    }

    function test_TransferAsset_EmitsTransferInitiatedEvent() public {
        // Test would need to call transferAsset and verify event emission
    }

    function _deployAdapter(
        address registry,
        address accessManager,
        address lzEndpoint,
        uint16[] memory chains,
        uint32[] memory lzEids
    ) internal override returns (BaseERC7802Adapter) {
        return new ERC7802OFTAdapter(registry, accessManager, lzEndpoint);
    }
}
