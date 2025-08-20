// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title SummerTaxiCodec
 * @notice Decodes Stargate-V2 “taxi” messages and exposes a simple helper.
 */
library SummerTaxiCodec {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidMessage();

    /*//////////////////////////////////////////////////////////////
    /*------------------------------------------------------------------*\
    |  Layout constants                                                 |
    |  <1-byte type><2-byte assetId><32-byte receiver><8-byte amountSD> |
    |  <32-byte srcSender><bytes composeMsg>                            |
    \*------------------------------------------------------------------*/
    uint8 internal constant MSG_TYPE_TAXI = 1;
    uint256 internal constant MSG_TYPE_OFFSET = 1;
    uint256 internal constant ASSET_ID_OFFSET = 3;
    uint256 internal constant RECEIVER_OFFSET = 35; // 3 + 32
    uint256 internal constant AMOUNT_SD_OFFSET = 43; // 35 + 8
    uint256 internal constant SENDER_OFFSET = 75; // 43 + 32

    uint256 internal constant MIN_TAXI_LEN = SENDER_OFFSET + 1; // header + ≥1 byte payload

    /// @return True if `_bytes` starts with the taxi message type byte.
    function isTaxi(bytes calldata _bytes) internal pure returns (bool) {
        return _bytes.length > 0 && uint8(_bytes[0]) == MSG_TYPE_TAXI;
    }

    /**
     * @dev Decodes a taxi message and returns all components, incl. sender.
     */
    function decodeTaxi(
        bytes calldata _taxiBytes
    )
        internal
        pure
        returns (
            uint16 assetId,
            bytes32 receiver,
            uint64 amountSD,
            address srcSender,
            bytes memory composeMsg
        )
    {
        if (_taxiBytes.length < MIN_TAXI_LEN || !isTaxi(_taxiBytes)) {
            revert InvalidMessage();
        }

        assetId = uint16(bytes2(_taxiBytes[MSG_TYPE_OFFSET:ASSET_ID_OFFSET]));
        receiver = bytes32(_taxiBytes[ASSET_ID_OFFSET:RECEIVER_OFFSET]);
        amountSD = uint64(bytes8(_taxiBytes[RECEIVER_OFFSET:AMOUNT_SD_OFFSET]));

        srcSender = address(
            uint160(
                uint256(bytes32(_taxiBytes[AMOUNT_SD_OFFSET:SENDER_OFFSET]))
            )
        );

        composeMsg = _taxiBytes[SENDER_OFFSET:];
    }
}
