// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";
import {CrossChainRegistry} from "../../../src/contracts/CrossChainRegistry.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";

contract ExposedAdapter is BaseBridgeAdapter {
    constructor(
        address _registry,
        address _accessManager
    ) BaseBridgeAdapter(_registry, _accessManager) {}

    function onlyTrusted(
        uint16 dstChain
    ) external onlyTrustedDestination(dstChain) {}

    function exposed_validateTrustedSource(
        address srcAdapter,
        uint16 srcChain
    ) external view returns (bool) {
        return _validateTrustedSource(srcAdapter, srcChain);
    }

    function exposed_validateSourceChainId(
        uint16 sourceChainId,
        uint16 expected
    ) external pure {
        _validateSourceChainId(sourceChainId, expected);
    }

    function exposed_externalIdForChain(
        uint16 chainId
    ) external view returns (uint32) {
        return _externalIdForChain(chainId);
    }

    function exposed_chainIdFromExternalId(
        uint32 externalId
    ) external view returns (uint16) {
        return _chainIdFromExternalId(externalId);
    }

    function exposed_requireGasLimit(
        uint64 gasLimit
    ) external pure returns (uint64) {
        return _requireGasLimit(gasLimit);
    }

    function exposed_decodePayload(
        bytes calldata payload
    ) external pure returns (BridgeTypes.OperationType op, bytes memory data) {
        return _decodePayload(payload);
    }

    function exposed_encodeRelayedMessageParams(
        BridgeTypes.RelayedMessageParams memory p
    ) external pure returns (bytes memory) {
        return _encodeRelayedMessageParams(p);
    }

    function exposed_encodeRelayedTransferParams(
        BridgeTypes.RelayedTransferParams memory p
    ) external pure returns (bytes memory) {
        return _encodeRelayedTransferParams(p);
    }

    function exposed_encodeRelayedMessageParamsWithType(
        BridgeTypes.RelayedMessageParams memory p
    ) external pure returns (bytes memory) {
        return _encodeRelayedMessageParamsWithType(p);
    }

    function exposed_encodeRelayedTransferParamsWithType(
        BridgeTypes.RelayedTransferParams memory p
    ) external pure returns (bytes memory) {
        return _encodeRelayedTransferParamsWithType(p);
    }
}

contract BaseBridgeAdapterCoreTest is Test {
    address public governor = address(0xA11CE);
    address public user = address(0xB0B);

    ProtocolAccessManager public accessManager;
    CrossChainRegistry public registry;
    ExposedAdapter public adapterA;
    ExposedAdapter public adapterB;
    ExposedAdapter public adapterB2;

    event ExternalIdMapped(uint16 indexed chainId, uint32 indexed externalId);
    event ExternalIdUnmapped(uint16 indexed chainId, uint32 indexed externalId);

    function setUp() public {
        vm.startPrank(governor);
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistry(address(accessManager));
        adapterA = new ExposedAdapter(
            address(registry),
            address(accessManager)
        );
        adapterB = new ExposedAdapter(
            address(registry),
            address(accessManager)
        );
        adapterB2 = new ExposedAdapter(
            address(registry),
            address(accessManager)
        );
        vm.stopPrank();
    }

    // -------- Constructor --------
    function testConstructor_Reverts_WhenAccessManagerZero() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAccessManagerAddress(address)",
                address(0)
            )
        );
        new ExposedAdapter(address(registry), address(0));
    }

    // -------- supportsInterface --------
    function testSupportsInterface() public view {
        assertTrue(
            adapterA.supportsInterface(type(IBridgeAdapter).interfaceId)
        );
        assertTrue(adapterA.supportsInterface(type(IERC165).interfaceId));
    }

    // -------- External ID mapping / unmapping --------
    function testMapExternalId_AndResolveBothWays() public {
        uint16 chainId = 1337;
        uint32 eid = 9999;

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit ExternalIdMapped(chainId, eid);
        adapterA.mapExternalId(chainId, eid);
        vm.stopPrank();

        // resolve forward/backward via internal wrappers
        assertEq(adapterA.exposed_externalIdForChain(chainId), eid);
        assertEq(adapterA.exposed_chainIdFromExternalId(eid), chainId);
    }

    function testMapExternalId_Reverts_WhenExternalIdZero() public {
        vm.startPrank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidParams.selector
            )
        );
        adapterA.mapExternalId(1234, 0);
        vm.stopPrank();
    }

    function testUnmapExternalId_EmitsAndClears() public {
        uint16 chainId = 2000;
        uint32 eid = 7777;
        vm.startPrank(governor);
        adapterA.mapExternalId(chainId, eid);

        vm.expectEmit(true, true, false, true);
        emit ExternalIdUnmapped(chainId, eid);
        adapterA.unmapExternalId(chainId);
        vm.stopPrank();

        // Forward resolution should now revert with UnsupportedChain
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector)
        );
        adapterA.exposed_externalIdForChain(chainId);

        // Reverse resolution should also revert
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector)
        );
        adapterA.exposed_chainIdFromExternalId(eid);
    }

    // -------- Gas limit validation --------
    function testRequireGasLimit_RevertsOnZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidParams.selector
            )
        );
        adapterA.exposed_requireGasLimit(0);
    }

    function testRequireGasLimit_ReturnsValue() public view {
        assertEq(adapterA.exposed_requireGasLimit(1234), 1234);
    }

    // -------- Registry peer trust checks --------
    function testOnlyTrustedDestination_RevertAndPass() public {
        uint16 chainA = uint16(block.chainid);
        uint16 chainB = 4321;

        // Not trusted yet
        vm.expectRevert(
            abi.encodeWithSignature("UntrustedDestinationChain(uint16)", chainB)
        );
        adapterA.onlyTrusted(chainB);

        // Register peers
        vm.startPrank(governor);
        registry.registerAdapterPeerPair(
            address(adapterA),
            address(adapterB),
            chainA,
            chainB
        );
        vm.stopPrank();

        // Now passes
        adapterA.onlyTrusted(chainB);
        assertTrue(adapterA.isAllowedDestination(chainB));
    }

    function testGetPeeredChainIds_ReturnsAllTargets() public {
        uint16 chainA = uint16(block.chainid);
        uint16 chainB = 1111;
        uint16 chainC = 2222;

        vm.startPrank(governor);
        registry.registerAdapterPeerPair(
            address(adapterA),
            address(adapterB),
            chainA,
            chainB
        );
        registry.registerAdapterPeerPair(
            address(adapterA),
            address(adapterB2),
            chainA,
            chainC
        );
        vm.stopPrank();

        uint16[] memory chains = adapterA.getPeeredChainIds();
        assertEq(chains.length, 2);

        // Order not guaranteed; check membership
        bool hasB = (chains[0] == chainB) || (chains[1] == chainB);
        bool hasC = (chains[0] == chainC) || (chains[1] == chainC);
        assertTrue(hasB && hasC);
    }

    // -------- Source chain id assertion --------
    function testAssertSourceChainId_RevertOnMismatch() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidSourceChainId.selector
            )
        );
        adapterA.exposed_validateSourceChainId(100, 200);
    }

    function testAssertSourceChainId_PassOnMatch() public view {
        adapterA.exposed_validateSourceChainId(123, 123);
    }

    // -------- Encode/Decode helpers --------
    function testEncodeDecode_Message_WithType() public view {
        BridgeTypes.RelayedMessageParams memory p = BridgeTypes
            .RelayedMessageParams({
                operationId: keccak256("op1"),
                originator: address(this),
                sourceChainId: 7,
                recipient: address(0xBEEF),
                message: hex"010203"
            });

        bytes memory payload = adapterA
            .exposed_encodeRelayedMessageParamsWithType(p);
        (BridgeTypes.OperationType op, bytes memory data) = adapterA
            .exposed_decodePayload(payload);
        assertEq(uint256(op), uint256(BridgeTypes.OperationType.MESSAGE));

        // Also decode the inner struct
        BridgeTypes.RelayedMessageParams memory decoded = abi.decode(
            data,
            (BridgeTypes.RelayedMessageParams)
        );
        assertEq(decoded.operationId, p.operationId);
        assertEq(decoded.originator, p.originator);
        assertEq(decoded.sourceChainId, p.sourceChainId);
        assertEq(decoded.recipient, p.recipient);
        assertEq(decoded.message, p.message);
    }

    function testEncodeDecode_Transfer_WithType() public view {
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("op2"),
                originator: address(this),
                sourceChainId: 8,
                recipient: address(0xCAFE),
                asset: address(0xDEAD),
                amount: 12345,
                message: hex"aabbcc"
            });

        bytes memory payload = adapterA
            .exposed_encodeRelayedTransferParamsWithType(p);
        (BridgeTypes.OperationType op, bytes memory data) = adapterA
            .exposed_decodePayload(payload);
        assertEq(
            uint256(op),
            uint256(BridgeTypes.OperationType.TRANSFER_ASSET)
        );

        BridgeTypes.RelayedTransferParams memory decoded = abi.decode(
            data,
            (BridgeTypes.RelayedTransferParams)
        );
        assertEq(decoded.operationId, p.operationId);
        assertEq(decoded.originator, p.originator);
        assertEq(decoded.sourceChainId, p.sourceChainId);
        assertEq(decoded.recipient, p.recipient);
        assertEq(decoded.asset, p.asset);
        assertEq(decoded.amount, p.amount);
        assertEq(decoded.message, p.message);
    }
}
