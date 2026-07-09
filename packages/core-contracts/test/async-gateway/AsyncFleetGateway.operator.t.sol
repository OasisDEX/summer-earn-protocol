// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IERC7540Operator} from "../../src/interfaces/async-gateway/IERC7540.sol";

contract AsyncFleetGatewayOperatorTest is AsyncFleetGatewayTestBase {
    function test_AFG0101_SetOperatorSetsAndEmits() public {
        vm.expectEmit(true, true, false, true);
        emit IERC7540Operator.OperatorSet(alice, bob, true);
        vm.prank(alice);
        assertTrue(gateway.setOperator(bob, true));
        assertTrue(gateway.isOperator(alice, bob));
    }

    function test_AFG0102_SetOperatorRevoke() public {
        vm.startPrank(alice);
        gateway.setOperator(bob, true);
        gateway.setOperator(bob, false);
        vm.stopPrank();
        assertFalse(gateway.isOperator(alice, bob));
    }

    function test_AFG0103_DefaultNotOperator() public view {
        assertFalse(gateway.isOperator(alice, bob));
    }
}
