// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

abstract contract BaseBridgeAdapter {
    ICrossChainRegistry public immutable registry;
    uint16 public immutable THIS_CHAIN;

    constructor(address _registry) {
        registry = ICrossChainRegistry(_registry);
        THIS_CHAIN = uint16(block.chainid);
    }

    modifier onlySupportedDestination(uint16 dstChain) {
        require(
            registry.getAdapterPeer(address(this), dstChain) != address(0),
            "Unsupported destination chain"
        );
        _;
    }

    modifier onlyTrustedSource(address srcAdapter, uint16 srcChain) {
        require(
            registry.isValidAdapterPeer(
                srcAdapter,
                address(this),
                srcChain,
                THIS_CHAIN
            ),
            "Untrusted source adapter"
        );
        _;
    }

    function _peerAdapter(uint16 dstChain) internal view returns (address) {
        return registry.getAdapterPeer(address(this), dstChain);
    }
}
