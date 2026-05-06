// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

struct SupportedStablecoin {
    address sweepDestination;
    uint96 fee;
}

interface ISuperstateToken {
    function supportedStablecoins(
        address stablecoin
    ) external view returns (SupportedStablecoin memory);
}
