// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract SummerTokenPermitTest is SummerTokenTestBase {
    address public alice;
    address public bob;
    uint256 public alicePrivateKey;

    function setUp() public virtual override {
        super.setUp();
        alicePrivateKey = 0xA11CE;
        alice = vm.addr(alicePrivateKey);
        bob = makeAddr("bob");
        enableTransfers();

        // Transfer some tokens to alice for testing
        aSummerToken.transfer(alice, 100 ether);
    }

    function test_Permit() public {
        uint256 value = 50 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = aSummerToken.nonces(alice);

        bytes32 DOMAIN_SEPARATOR = aSummerToken.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                alice,
                bob,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        aSummerToken.permit(alice, bob, value, deadline, v, r, s);

        assertEq(aSummerToken.allowance(alice, bob), value);
        assertEq(aSummerToken.nonces(alice), 1);
    }

    function test_RevertWhen_PermitExpired() public {
        uint256 value = 50 ether;
        uint256 deadline = block.timestamp - 1; // expired deadline
        uint256 nonce = aSummerToken.nonces(alice);

        bytes32 DOMAIN_SEPARATOR = aSummerToken.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                alice,
                bob,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Expect the custom error ERC2612ExpiredSignature with the deadline parameter
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC2612ExpiredSignature(uint256)",
                deadline
            )
        );

        aSummerToken.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_RevertWhen_InvalidSignature() public {
        uint256 value = 50 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = aSummerToken.nonces(alice);

        bytes32 DOMAIN_SEPARATOR = aSummerToken.DOMAIN_SEPARATOR();

        // Create the permit hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                alice,
                bob,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        // Sign with a different private key to create an invalid signature
        uint256 wrongPrivateKey = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC2612InvalidSigner(address,address)",
                vm.addr(wrongPrivateKey),
                alice
            )
        );

        // Try to permit with invalid signature
        aSummerToken.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_PermitWithTransfer() public {
        uint256 value = 50 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = aSummerToken.nonces(alice);

        bytes32 DOMAIN_SEPARATOR = aSummerToken.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                alice,
                bob,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Execute permit
        aSummerToken.permit(alice, bob, value, deadline, v, r, s);

        // Use the allowance to transfer tokens
        vm.prank(bob);
        aSummerToken.transferFrom(alice, bob, value);

        // Verify final balances
        assertEq(aSummerToken.balanceOf(alice), 50 ether);
        assertEq(aSummerToken.balanceOf(bob), value);
        assertEq(aSummerToken.allowance(alice, bob), 0);
    }
}
