// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1155FullSupplyMock} from "../mocks/ERC1155FullSupplyMock.sol";

contract ERC1155FullSupplyTest is Test {
    ERC1155FullSupplyMock public token;
    address public holder = address(0x1);
    string public constant URI = "https://token.com";

    uint256 public constant FIRST_TOKEN_ID = 37;
    uint256 public constant FIRST_TOKEN_AMOUNT = 42;

    uint256 public constant SECOND_TOKEN_ID = 19842;
    uint256 public constant SECOND_TOKEN_AMOUNT = 23;

    function setUp() public {
        token = new ERC1155FullSupplyMock(URI);
    }

    // Context: before mint
    function test_BeforeMint_Exists() public view {
        assertFalse(token.exists(FIRST_TOKEN_ID));
    }

    function test_BeforeMint_TotalSupply() public view {
        assertEq(token.totalSupply(FIRST_TOKEN_ID), 0);
    }

    function test_BeforeMint_BalanceOfAll() public view {
        assertEq(token.balanceOfAll(holder), 0);
    }

    // Context: after mint single
    function test_AfterMint_Single_Exists() public {
        vm.prank(holder); // Not strictly needed for mint but good practice if checks were strict
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");

        assertTrue(token.exists(FIRST_TOKEN_ID));
    }

    function test_AfterMint_Single_TotalSupply() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");

        assertEq(token.totalSupply(FIRST_TOKEN_ID), FIRST_TOKEN_AMOUNT);
    }

    function test_AfterMint_Single_BalanceOfAll() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");

        assertEq(token.balanceOfAll(holder), FIRST_TOKEN_AMOUNT);
    }

    // Context: after mint single again
    function test_AfterMint_SingleAgain_Exists() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.mint(holder, SECOND_TOKEN_ID, SECOND_TOKEN_AMOUNT, "");

        assertTrue(token.exists(FIRST_TOKEN_ID));
    }

    function test_AfterMint_SingleAgain_TotalSupply() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.mint(holder, SECOND_TOKEN_ID, SECOND_TOKEN_AMOUNT, "");

        assertEq(token.totalSupply(FIRST_TOKEN_ID), FIRST_TOKEN_AMOUNT);
    }

    function test_AfterMint_SingleAgain_BalanceOfAll() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.mint(holder, SECOND_TOKEN_ID, SECOND_TOKEN_AMOUNT, "");

        assertEq(
            token.balanceOfAll(holder),
            FIRST_TOKEN_AMOUNT + SECOND_TOKEN_AMOUNT
        );
    }

    // Context: after mint batch
    function test_AfterMint_Batch_Exists() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");

        assertTrue(token.exists(FIRST_TOKEN_ID));
        assertTrue(token.exists(SECOND_TOKEN_ID));
    }

    function test_AfterMint_Batch_TotalSupply() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");

        assertEq(token.totalSupply(FIRST_TOKEN_ID), FIRST_TOKEN_AMOUNT);
        assertEq(token.totalSupply(SECOND_TOKEN_ID), SECOND_TOKEN_AMOUNT);
    }

    function test_AfterMint_Batch_BalanceOfAll() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");

        assertEq(
            token.balanceOfAll(holder),
            FIRST_TOKEN_AMOUNT + SECOND_TOKEN_AMOUNT
        );
    }

    // Context: after burn single
    function test_AfterBurn_Single_Exists() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.burn(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT);

        assertFalse(token.exists(FIRST_TOKEN_ID));
    }

    function test_AfterBurn_Single_TotalSupply() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.burn(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT);

        assertEq(token.totalSupply(FIRST_TOKEN_ID), 0);
    }

    function test_AfterBurn_Single_BalanceOfAll() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.burn(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT);

        assertEq(token.balanceOfAll(holder), 0);
    }

    // Context: double, burn only one
    function test_AfterBurn_Double_BurnOne_Exists() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.mint(holder, SECOND_TOKEN_ID, SECOND_TOKEN_AMOUNT, "");
        token.burn(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT);

        assertFalse(token.exists(FIRST_TOKEN_ID));
        assertTrue(token.exists(SECOND_TOKEN_ID));
    }

    function test_AfterBurn_Double_BurnOne_TotalSupply() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.mint(holder, SECOND_TOKEN_ID, SECOND_TOKEN_AMOUNT, "");
        token.burn(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT);

        assertEq(token.totalSupply(FIRST_TOKEN_ID), 0);
        assertEq(token.totalSupply(SECOND_TOKEN_ID), SECOND_TOKEN_AMOUNT);
    }

    function test_AfterBurn_Double_BurnOne_BalanceOfAll() public {
        token.mint(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT, "");
        token.mint(holder, SECOND_TOKEN_ID, SECOND_TOKEN_AMOUNT, "");
        token.burn(holder, FIRST_TOKEN_ID, FIRST_TOKEN_AMOUNT);

        assertEq(token.balanceOfAll(holder), SECOND_TOKEN_AMOUNT);
    }

    // Context: batch burn
    function test_AfterBurn_Batch_Exists() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");
        token.burnBatch(holder, ids, amounts);

        assertFalse(token.exists(FIRST_TOKEN_ID));
        assertFalse(token.exists(SECOND_TOKEN_ID));
    }

    function test_AfterBurn_Batch_TotalSupply() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");
        token.burnBatch(holder, ids, amounts);

        assertEq(token.totalSupply(FIRST_TOKEN_ID), 0);
        assertEq(token.totalSupply(SECOND_TOKEN_ID), 0);
    }

    function test_AfterBurn_Batch_BalanceOfAll() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");
        token.burnBatch(holder, ids, amounts);

        assertEq(token.balanceOfAll(holder), 0);
    }

    // Context: batch burn only one
    function test_AfterBurn_Batch_BurnOne_Exists() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");

        uint256[] memory burnIds = new uint256[](1);
        burnIds[0] = SECOND_TOKEN_ID;
        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = SECOND_TOKEN_AMOUNT;

        token.burnBatch(holder, burnIds, burnAmounts);

        assertTrue(token.exists(FIRST_TOKEN_ID));
        assertFalse(token.exists(SECOND_TOKEN_ID));
    }

    function test_AfterBurn_Batch_BurnOne_TotalSupply() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");

        uint256[] memory burnIds = new uint256[](1);
        burnIds[0] = SECOND_TOKEN_ID;
        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = SECOND_TOKEN_AMOUNT;

        token.burnBatch(holder, burnIds, burnAmounts);

        assertEq(token.totalSupply(FIRST_TOKEN_ID), FIRST_TOKEN_AMOUNT);
        assertEq(token.totalSupply(SECOND_TOKEN_ID), 0);
    }

    function test_AfterBurn_Batch_BurnOne_BalanceOfAll() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = FIRST_TOKEN_ID;
        ids[1] = SECOND_TOKEN_ID;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = FIRST_TOKEN_AMOUNT;
        amounts[1] = SECOND_TOKEN_AMOUNT;

        token.mintBatch(holder, ids, amounts, "");

        uint256[] memory burnIds = new uint256[](1);
        burnIds[0] = SECOND_TOKEN_ID;
        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = SECOND_TOKEN_AMOUNT;

        token.burnBatch(holder, burnIds, burnAmounts);

        assertEq(token.balanceOfAll(holder), FIRST_TOKEN_AMOUNT);
    }
}
