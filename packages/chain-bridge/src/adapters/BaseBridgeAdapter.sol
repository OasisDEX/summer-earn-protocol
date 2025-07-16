// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

abstract contract BaseBridgeAdapter is
    CrossChainConfigManaged,
    ReentrancyGuard,
    ProtocolAccessManaged
{
    /// @notice Error thrown when destination chain is not supported
    error UnsupportedDestinationChain(uint16 chainId);

    /// @notice Error thrown when source adapter is not trusted
    error UntrustedSourceAdapter(address srcAdapter, uint16 srcChain);

    /// @notice Error thrown when chain ID exceeds uint16 max value
    error ChainIdTooLarge(uint256 chainId);

    ICrossChainRegistry public immutable REGISTRY;
    uint16 public immutable THIS_CHAIN;

    /**
     * @param _registry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     */
    constructor(
        address _registry,
        address _accessManager
    ) CrossChainConfigManaged(_registry) ProtocolAccessManaged(_accessManager) {
        REGISTRY = ICrossChainRegistry(_registry);
        if (block.chainid > type(uint16).max) {
            revert ChainIdTooLarge(block.chainid);
        }
        THIS_CHAIN = uint16(block.chainid);
    }

    modifier onlySupportedDestination(uint16 dstChain) {
        if (REGISTRY.getAdapterPeer(address(this), dstChain) == address(0)) {
            revert UnsupportedDestinationChain(dstChain);
        }
        _;
    }

    modifier onlyTrustedSource(address srcAdapter, uint16 srcChain) {
        if (
            !REGISTRY.isValidAdapterPeer(
                srcAdapter,
                address(this),
                srcChain,
                THIS_CHAIN
            )
        ) {
            revert UntrustedSourceAdapter(srcAdapter, srcChain);
        }
        _;
    }

    /**
     * @notice Get the list of supported chains
     */
    function getSupportedChains()
        external
        view
        returns (uint16[] memory chains)
    {
        (, uint16[] memory targetChainIds) = REGISTRY.getTargetsForSource(
            address(this),
            REGISTRY.PEER()
        );
        return targetChainIds;
    }

    function _peerAdapter(uint16 dstChain) internal view returns (address) {
        return REGISTRY.getAdapterPeer(address(this), dstChain);
    }
}
