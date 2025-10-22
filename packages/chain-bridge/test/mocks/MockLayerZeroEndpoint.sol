// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";

/**
 * @title MockLayerZeroEndpoint
 * @notice Mock LayerZero endpoint for testing compose functionality
 */
contract MockLayerZeroEndpoint {
    mapping(address => bool) public validComposers;

    // Track compose calls for testing
    struct ComposeCall {
        address to;
        bytes32 guid;
        uint16 index;
        bytes message;
    }

    ComposeCall[] public composeCalls;
    mapping(bytes32 => bool) public executedComposes;

    event ComposeSent(
        address indexed from,
        address indexed to,
        bytes32 indexed guid,
        uint16 index,
        bytes message
    );

    function setValidComposer(address composer, bool valid) external {
        validComposers[composer] = valid;
    }

    /**
     * @notice Mock sendCompose function that stores compose calls
     * @param _to The address to send the compose message to
     * @param _guid The message GUID
     * @param _index The compose index
     * @param _message The compose message
     */
    function sendCompose(
        address _to,
        bytes32 _guid,
        uint16 _index,
        bytes calldata _message
    ) external {
        // Store the compose call
        composeCalls.push(
            ComposeCall({
                to: _to,
                guid: _guid,
                index: _index,
                message: _message
            })
        );

        emit ComposeSent(msg.sender, _to, _guid, _index, _message);
    }

    /**
     * @notice Execute a stored compose call (for testing)
     * @param composeIndex The index of the compose call to execute
     * @param executor The executor address to use
     * @param extraData Extra data to pass
     */
    function executeCompose(
        uint256 composeIndex,
        address executor,
        bytes calldata extraData
    ) external {
        require(composeIndex < composeCalls.length, "Invalid compose index");

        ComposeCall memory call = composeCalls[composeIndex];
        bytes32 composeKey = keccak256(
            abi.encode(call.to, call.guid, call.index)
        );

        require(!executedComposes[composeKey], "Compose already executed");
        executedComposes[composeKey] = true;

        // Call lzCompose on the target contract
        IOAppComposer(call.to).lzCompose(
            msg.sender, // oApp (the caller)
            call.guid,
            call.message,
            executor,
            extraData
        );
    }

    /**
     * @notice Get the number of compose calls
     */
    function getComposeCallsLength() external view returns (uint256) {
        return composeCalls.length;
    }

    /**
     * @notice Get a specific compose call
     */
    function getComposeCall(
        uint256 index
    )
        external
        view
        returns (
            address to,
            bytes32 guid,
            uint16 composeIndex,
            bytes memory message
        )
    {
        require(index < composeCalls.length, "Invalid index");
        ComposeCall memory call = composeCalls[index];
        return (call.to, call.guid, call.index, call.message);
    }

    /**
     * @notice Clear all compose calls (for test cleanup)
     */
    function clearComposeCalls() external {
        delete composeCalls;
    }

    function testSkipper() public {}
}
