// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {console} from "forge-std/console.sol";

contract SummerTokenCappedTest is SummerTokenTestBase {
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

    function test_InitialState() public view {
        assertEq(aSummerToken.cap(), MAX_SUPPLY, "Cap should be set correctly");
        assertEq(
            aSummerToken.totalSupply(),
            INITIAL_SUPPLY * 1e18,
            "Initial supply should be set correctly"
        );
    }

    function test_MintUpToCap() public {
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), address(this), remainingToMint);

        // Mint remaining tokens up to cap
        aSummerToken.mint(address(this), remainingToMint);

        assertEq(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should equal cap"
        );
    }

    function test_CannotMintBeyondCap() public {
        uint256 remainingToMint = MAX_SUPPLY - (INITIAL_SUPPLY * 1e18);

        // First mint up to cap
        aSummerToken.mint(address(this), remainingToMint);

        // Try to mint 1 more token
        vm.expectRevert();
        aSummerToken.mint(address(this), 1);
    }

    function test_MintExactlyAtCap() public {
        uint256 remainingToMint = MAX_SUPPLY - (INITIAL_SUPPLY * 1e18);
        aSummerToken.mint(address(this), remainingToMint);
        assertEq(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Should be able to mint exactly to cap"
        );
    }

    function test_BurnAndRemint() public {
        // Burn some tokens
        uint256 burnAmount = 1000e18;
        aSummerToken.burn(burnAmount);

        // Should be able to mint the burned amount
        aSummerToken.mint(address(this), burnAmount);
        assertEq(
            aSummerToken.totalSupply(),
            INITIAL_SUPPLY * 1e18,
            "Should be able to remint burned tokens"
        );
    }

    function test_MultipleMintOperations() public {
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        uint256 mintAmount = remainingToMint / 3;

        // Mint in three operations
        aSummerToken.mint(address(this), mintAmount);
        aSummerToken.mint(address(this), mintAmount);
        aSummerToken.mint(address(this), remainingToMint - (2 * mintAmount)); // Remaining amount

        assertEq(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should equal cap after multiple mints"
        );
    }

    function test_CapRemainsConstant() public {
        uint256 initialCap = aSummerToken.cap();

        // Perform various operations
        aSummerToken.burn(1000e18);
        aSummerToken.mint(address(this), 500e18);

        assertEq(aSummerToken.cap(), initialCap, "Cap should remain constant");
    }

    function test_MintToMultipleAccounts() public {
        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        uint256 mintAmount = remainingToMint / 2;

        aSummerToken.mint(alice, mintAmount);
        aSummerToken.mint(bob, mintAmount);

        assertEq(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Total supply should be correct"
        );
        assertEq(
            aSummerToken.balanceOf(alice),
            mintAmount,
            "Alice balance should be correct"
        );
        assertEq(
            aSummerToken.balanceOf(bob),
            mintAmount,
            "Bob balance should be correct"
        );
    }

    function test_BurnAndMintCombinations() public {
        // Burn from owner
        aSummerToken.burn(500e18);

        // Initial mint to alice
        aSummerToken.mint(alice, 200e18);

        // Mint to bob the difference between the burned amount and the minted amount
        aSummerToken.mint(bob, 500e18 - 200e18);

        // Have alice burn some tokens
        vm.prank(alice);
        aSummerToken.burn(200e18);

        // Mint the burned amount to charlie
        aSummerToken.mint(charlie, 200e18);

        assertEq(
            aSummerToken.totalSupply(),
            aSummerToken.cap(),
            "Final supply should match expected"
        );
    }

    function test_MintAfterComplexOperations() public {
        aSummerToken.burn(aSummerToken.totalSupply());

        // Mint smaller amounts to avoid cap issues
        aSummerToken.mint(alice, 500e18);

        vm.prank(alice);
        aSummerToken.transfer(bob, 500e18);

        vm.prank(bob);
        aSummerToken.burn(250e18);

        uint256 remainingToMint = MAX_SUPPLY - aSummerToken.totalSupply();
        aSummerToken.mint(charlie, remainingToMint);

        assertEq(
            aSummerToken.totalSupply(),
            MAX_SUPPLY,
            "Should be able to mint up to cap after complex operations"
        );
    }
}
