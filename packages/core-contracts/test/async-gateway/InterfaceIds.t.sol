// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC7540Operator, IERC7540Deposit, IERC7540Redeem} from "../../src/interfaces/async-gateway/IERC7540.sol";

/// @dev ERC-7540 mandates these exact ERC-165 ids. If a signature in our interface
///      declarations drifts from the spec, these assertions catch it at compile+test time.
contract InterfaceIdsTest is Test {
    function test_IID0001_OperatorInterfaceId() public pure {
        assertEq(
            bytes4(type(IERC7540Operator).interfaceId),
            bytes4(0xe3bc4e65)
        );
    }

    function test_IID0002_AsyncDepositInterfaceId() public pure {
        assertEq(bytes4(type(IERC7540Deposit).interfaceId), bytes4(0xce3bbe50));
    }

    function test_IID0003_AsyncRedeemInterfaceId() public pure {
        assertEq(bytes4(type(IERC7540Redeem).interfaceId), bytes4(0x620ee8e4));
    }
}
