// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {IOAppPreCrimeSimulator, InboundPacket, Origin} from "@layerzerolabs/oapp-evm/contracts/precrime/interfaces/IOAppPreCrimeSimulator.sol";

contract SummerTokenPreCrimeTest is SummerTokenTestBase {
    address public constant PRECRIME = address(0x123);

    function test_SetPreCrime() public {
        vm.prank(owner);
        aSummerToken.setPreCrime(PRECRIME);
        assertEq(aSummerToken.preCrime(), PRECRIME);
    }

    function test_RevertWhenNonTrustedPeerInPreCrime() public {
        vm.prank(owner);
        aSummerToken.setPreCrime(PRECRIME);

        // Create an array with a single packet
        InboundPacket[] memory packets = new InboundPacket[](1);
        packets[0] = InboundPacket({
            origin: Origin({
                srcEid: bEid,
                sender: addressToBytes32(address(0xdead)), // Non-trusted peer
                nonce: 1
            }),
            dstEid: aEid,
            receiver: address(aSummerToken),
            guid: bytes32(0),
            value: 0,
            executor: address(0),
            message: "",
            extraData: ""
        });

        vm.prank(PRECRIME);
        vm.expectRevert();
        aSummerToken.lzReceiveAndRevert(packets);
    }
}
