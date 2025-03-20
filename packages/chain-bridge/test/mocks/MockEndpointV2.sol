// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";

contract MockEndpointV2 {
    function lzReceive(
        address _oapp,
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external {}

    function quote(
        uint32,
        bytes calldata,
        bytes calldata,
        bool
    ) external pure returns (MessagingFee memory) {
        // Return a mock fee for testing
        return MessagingFee(0.01 ether, 0);
    }

    function send(
        uint32,
        bytes calldata _message,
        bytes calldata,
        MessagingFee calldata,
        address payable
    ) external payable returns (bytes32) {
        // Return a mock receipt
        return bytes32(keccak256(abi.encodePacked(_message)));
    }
}
