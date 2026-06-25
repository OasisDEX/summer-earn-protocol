// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Permit2Consumer} from "../../../src/utils/Permit2Consumer.sol";
import {IPermit2, IAllowanceTransfer} from "../../../src/interfaces/permit2/IPermit2.sol";

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

    /*//////////////////////////////////////////////////////////////
        AllowanceTransfer.permit + allowance (for _applyPermit2Allowance)
    //////////////////////////////////////////////////////////////*/

    /// @notice When true, `permit` reverts — simulating a mempool front-run that
    ///         already consumed the signed nonce (`InvalidNonce`).
    bool public permitShouldRevert;

    /// @dev Live on-chain sub-allowance returned by `allowance` (the state the
    ///      front-run catch path inspects).
    uint160 public allowanceAmount;
    uint48 public allowanceExpiration;

    function setPermitRevert(bool _revert) external {
        permitShouldRevert = _revert;
    }

    function setAllowance(uint160 _amount, uint48 _expiration) external {
        allowanceAmount = _amount;
        allowanceExpiration = _expiration;
    }

    function permit(
        address,
        IAllowanceTransfer.PermitSingle calldata,
        bytes calldata
    ) external view {
        if (permitShouldRevert) revert("InvalidNonce");
    }

    function allowance(
        address,
        address,
        address
    ) external view returns (uint160, uint48, uint48) {
        return (allowanceAmount, allowanceExpiration, 0);
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

    function applyPermit2Allowance(
        address owner,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    ) external {
        _applyPermit2Allowance(owner, permitSingle, signature);
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

    /*//////////////////////////////////////////////////////////////
                          _applyPermit2Allowance
    //////////////////////////////////////////////////////////////*/

    uint160 internal constant SIGNED_AMOUNT = 1_000e6;

    /// @dev Builds a PermitSingle spent by `consumer`, signed for `SIGNED_AMOUNT`
    ///      and the given expiration. `nonce`/`sigDeadline` are irrelevant to the
    ///      catch-path checks under test.
    function _permitSingle(
        uint48 expiration
    ) internal view returns (IAllowanceTransfer.PermitSingle memory) {
        return
            IAllowanceTransfer.PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: TOKEN,
                    amount: SIGNED_AMOUNT,
                    expiration: expiration,
                    nonce: 0
                }),
                spender: address(consumer),
                sigDeadline: block.timestamp + 1 days
            });
    }

    function test_ApplyPermit2Allowance_RevertsOnWrongSpender() public {
        IAllowanceTransfer.PermitSingle memory ps = _permitSingle(
            uint48(block.timestamp + 30 days)
        );
        ps.spender = address(0xDEAD);

        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Spender.selector,
                address(consumer),
                address(0xDEAD)
            )
        );
        consumer.applyPermit2Allowance(OWNER, ps, "");
    }

    function test_ApplyPermit2Allowance_SucceedsWhenPermitSucceeds() public {
        // No front-run: permit() does not revert, so the catch path is never hit
        // (no allowance inspection required).
        consumer.applyPermit2Allowance(
            OWNER,
            _permitSingle(uint48(block.timestamp + 30 days)),
            ""
        );
    }

    function test_ApplyPermit2Allowance_FrontRun_RevertsWhenAmountInsufficient()
        public
    {
        mockPermit2.setPermitRevert(true);
        // Live allowance below the signed amount.
        mockPermit2.setAllowance(
            SIGNED_AMOUNT - 1,
            uint48(block.timestamp + 30 days)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.Permit2AllowanceNotSet.selector,
                SIGNED_AMOUNT,
                SIGNED_AMOUNT - 1
            )
        );
        consumer.applyPermit2Allowance(
            OWNER,
            _permitSingle(uint48(block.timestamp + 30 days)),
            ""
        );
    }

    /// @dev The P2-1 fix: even when the live allowance amount is sufficient, a
    ///      shorter-than-signed expiration must revert (front-run that set a
    ///      weaker expiration, or a stale pre-existing allowance).
    function test_ApplyPermit2Allowance_FrontRun_RevertsWhenExpirationTooEarly()
        public
    {
        uint48 signedExpiration = uint48(block.timestamp + 30 days);
        uint48 liveExpiration = uint48(block.timestamp + 1 days);

        mockPermit2.setPermitRevert(true);
        mockPermit2.setAllowance(SIGNED_AMOUNT, liveExpiration); // amount OK, expiration short

        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.Permit2ExpirationNotSet.selector,
                signedExpiration,
                liveExpiration
            )
        );
        consumer.applyPermit2Allowance(
            OWNER,
            _permitSingle(signedExpiration),
            ""
        );
    }

    function test_ApplyPermit2Allowance_FrontRun_SucceedsWhenAllowanceCovers()
        public
    {
        uint48 signedExpiration = uint48(block.timestamp + 30 days);

        mockPermit2.setPermitRevert(true);
        // Front-run replayed the same signed message: live allowance matches the
        // signed amount and expiration, so the catch path must proceed silently.
        mockPermit2.setAllowance(SIGNED_AMOUNT, signedExpiration);

        consumer.applyPermit2Allowance(
            OWNER,
            _permitSingle(signedExpiration),
            ""
        );
    }
}
