// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {console} from "forge-std/console.sol";

contract SummerTokenCappedFuzzTest is SummerTokenTestBase {
    event Transfer(address indexed from, address indexed to, uint256 value);

    address public alice;
    address public bob;
    address public charlie;

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        enableTransfers(); // Enable transfers for testing
    }

    // ... existing code ...

    function testFuzz_MintWithinCap(uint256 mintAmount) public {
        // Bound mintAmount to be between 0 and remaining capacity
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        mintAmount = bound(mintAmount, 0, remainingToMint);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), address(this), mintAmount);

        aSummerToken.mint(address(this), mintAmount);

        assertLe(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should not exceed cap"
        );
    }

    function testFuzz_MintToMultipleAccountsWithinCap(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 charlieAmount
    ) public {
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();

        // First bound individual amounts to prevent overflow
        aliceAmount = bound(aliceAmount, 0, remainingToMint);
        bobAmount = bound(bobAmount, 0, remainingToMint);
        charlieAmount = bound(charlieAmount, 0, remainingToMint);

        // Calculate sum and ensure it doesn't exceed remaining capacity
        uint256 sum = aliceAmount + bobAmount + charlieAmount;
        if (sum == 0) sum = 1; // Prevent division by zero

        // Distribute proportionally
        uint256 totalMintAmount = bound(sum, 0, remainingToMint);

        // Use SafeMath or checked arithmetic
        aliceAmount = (totalMintAmount * aliceAmount) / sum;
        bobAmount = (totalMintAmount * bobAmount) / sum;
        charlieAmount = totalMintAmount - aliceAmount - bobAmount; // Remainder to charlie

        // Perform mints
        if (aliceAmount > 0) aSummerToken.mint(alice, aliceAmount);
        if (bobAmount > 0) aSummerToken.mint(bob, bobAmount);
        if (charlieAmount > 0) aSummerToken.mint(charlie, charlieAmount);

        assertLe(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should not exceed cap"
        );
        assertEq(aSummerToken.balanceOf(alice), aliceAmount);
        assertEq(aSummerToken.balanceOf(bob), bobAmount);
        assertEq(aSummerToken.balanceOf(charlie), charlieAmount);
    }

    function testFuzz_BurnAndRemintWithinCap(
        uint256 burnAmount,
        uint256 remintAmount
    ) public {
        // Bound burn amount to current supply
        burnAmount = bound(burnAmount, 0, aSummerToken.totalSupply());

        // Burn tokens
        aSummerToken.burn(burnAmount);

        // Bound remint amount to not exceed cap
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        remintAmount = bound(remintAmount, 0, remainingToMint);

        aSummerToken.mint(address(this), remintAmount);

        assertLe(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should not exceed cap"
        );
    }

    function testFuzz_MintFailsAboveCap(uint256 excessAmount) public {
        // First mint up to cap
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        aSummerToken.mint(address(this), remainingToMint);

        // Try to mint additional amount above cap
        vm.assume(excessAmount > 0);

        vm.expectRevert();
        aSummerToken.mint(address(this), excessAmount);
    }

    function testFuzz_ComplexMintingSequence(
        uint256[3] memory mintAmounts,
        address[3] memory recipients
    ) public {
        // Filter out zero and invalid addresses
        for (uint256 i = 0; i < 3; i++) {
            // Ensure valid addresses (not zero address and not contract addresses)
            recipients[i] = address(
                uint160(uint256(keccak256(abi.encode(recipients[i]))))
            );
            vm.assume(recipients[i] != address(0));
            vm.assume(recipients[i] != address(aSummerToken));

            // Ensure unique addresses
            for (uint256 j = 0; j < i; j++) {
                vm.assume(recipients[i] != recipients[j]);
            }
        }

        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        uint256 maxPerMint = remainingToMint / 3; // Divide remaining capacity by number of mints

        // Pre-bound all mint amounts
        uint256[] memory boundedAmounts = new uint256[](3);
        uint256 totalMinted = 0;

        for (uint256 i = 0; i < 3; i++) {
            // Bound each amount to be at most maxPerMint
            boundedAmounts[i] = bound(mintAmounts[i], 0, maxPerMint);

            if (boundedAmounts[i] > 0) {
                aSummerToken.mint(recipients[i], boundedAmounts[i]);
                totalMinted += boundedAmounts[i];
            }
        }

        assertLe(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should not exceed cap"
        );

        // Verify individual balances
        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                aSummerToken.balanceOf(recipients[i]),
                boundedAmounts[i],
                "Balance should match minted amount"
            );
        }
    }
}
