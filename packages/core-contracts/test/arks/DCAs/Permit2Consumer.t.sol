// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Permit2Consumer} from "../../../src/utils/Permit2Consumer.sol";
import {IPermit2} from "../../../src/interfaces/permit2/IPermit2.sol";

/// @notice Minimal mock that records the last `transferFrom` call and can be
///         configured to revert, simulating an expired or exhausted allowance.
contract MockPermit2 {
    address public lastFrom;
    address public lastTo;
    uint160 public lastAmount;
    address public lastToken;

    bool public shouldRevert;
    string public revertMessage;

    function setRevert(bool _revert, string memory _msg) external {
        shouldRevert = _revert;
        revertMessage = _msg;
    }

    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external {
        if (shouldRevert) revert(revertMessage);
        lastFrom = from;
        lastTo = to;
        lastAmount = amount;
        lastToken = token;
    }
}

/// @notice Concrete implementation that exposes `_pullFunds` for testing.
contract TestablePermit2Consumer is Permit2Consumer {
    constructor(address _permit2) Permit2Consumer(_permit2) {}

    function pullFunds(
        address owner,
        address token,
        uint256 amount
    ) external returns (uint256) {
        return _pullFunds(owner, token, amount);
    }
}

contract Permit2ConsumerTest is Test {
    MockPermit2 public mockPermit2;
    TestablePermit2Consumer public consumer;

    address public constant TOKEN = address(0xAAA);
    address public constant OWNER = address(0xBBB);

    function setUp() public {
        mockPermit2 = new MockPermit2();
        consumer = new TestablePermit2Consumer(address(mockPermit2));
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZeroPermit2Address() public {
        vm.expectRevert(Permit2Consumer.InvalidPermit2Address.selector);
        new TestablePermit2Consumer(address(0));
    }

    function test_Constructor_SetsPermit2() public view {
        assertEq(address(consumer.PERMIT2()), address(mockPermit2));
    }

    /*//////////////////////////////////////////////////////////////
                              _pullFunds
    //////////////////////////////////////////////////////////////*/

    function test_PullFunds_RevertsWhenAmountExceedsUint160() public {
        uint256 overflow = uint256(type(uint160).max) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.AmountOverflowsUint160.selector,
                overflow
            )
        );
        consumer.pullFunds(OWNER, TOKEN, overflow);
    }

    function test_PullFunds_CallsPermit2WithCorrectArguments() public {
        uint256 amount = 1_000e6;

        consumer.pullFunds(OWNER, TOKEN, amount);

        assertEq(mockPermit2.lastFrom(), OWNER);
        assertEq(mockPermit2.lastTo(), address(consumer));
        assertEq(uint256(mockPermit2.lastAmount()), amount);
        assertEq(mockPermit2.lastToken(), TOKEN);
    }

    function test_PullFunds_ReturnsAmount() public {
        uint256 amount = 500e18;
        uint256 returned = consumer.pullFunds(OWNER, TOKEN, amount);
        assertEq(returned, amount);
    }

    function test_PullFunds_AcceptsUint160MaxAmount() public {
        uint256 maxAmount = type(uint160).max;
        uint256 returned = consumer.pullFunds(OWNER, TOKEN, maxAmount);
        assertEq(returned, maxAmount);
        assertEq(uint256(mockPermit2.lastAmount()), maxAmount);
    }

    function test_PullFunds_RevertsWhenPermit2Reverts() public {
        mockPermit2.setRevert(true, "ALLOWANCE_EXPIRED");

        vm.expectRevert(bytes("ALLOWANCE_EXPIRED"));
        consumer.pullFunds(OWNER, TOKEN, 100e6);
    }
}
