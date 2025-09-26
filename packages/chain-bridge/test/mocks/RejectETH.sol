// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

contract RejectETH {
    receive() external payable {
        revert("Transfer rejected");
    }

    function testSkipper() public {}
}
