// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../src/lib/TokenLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

contract MockToken is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

contract TokenLibraryTest is Test {
    using TokenLibrary for IERC20;

    MockToken public token0;
    MockToken public token6;
    MockToken public token8;
    MockToken public token18;
    MockToken public tokenNoDecimals;

    function setUp() public {
        token0 = new MockToken("Token0", "TKN0", 0);
        token6 = new MockToken("Token6", "TKN6", 6);
        token8 = new MockToken("Token8", "TKN8", 8);
        token18 = new MockToken("Token18", "TKN18", 18);
        tokenNoDecimals = new MockToken("TokenNoDecimals", "TKNN", 0);
    }

    function testGetDecimals() public view {
        assertEq(TokenLibrary.getDecimals(IERC20(address(token0))), 0);
        assertEq(TokenLibrary.getDecimals(IERC20(address(token6))), 6);
        assertEq(TokenLibrary.getDecimals(IERC20(address(token8))), 8);
        assertEq(TokenLibrary.getDecimals(IERC20(address(token18))), 18);
        assertEq(TokenLibrary.getDecimals(IERC20(address(tokenNoDecimals))), 0);
    }

    function testGetDecimalsWithNonERC20() public view {
        assertEq(TokenLibrary.getDecimals(IERC20(address(0x1))), 18);
    }

    function testToWei() public pure {
        // 0 decimals to 18 decimals
        assertEq(TokenLibrary.toWei(1, 0), 1e18);

        // 6 decimals to 18 decimals
        assertEq(TokenLibrary.toWei(1e6, 6), 1e18);
        assertEq(TokenLibrary.toWei(5e5, 6), 5e17);

        // 8 decimals to 18 decimals
        assertEq(TokenLibrary.toWei(1e8, 8), 1e18);
        assertEq(TokenLibrary.toWei(5e7, 8), 5e17);

        // 18 decimals to 18 decimals (no change)
        assertEq(TokenLibrary.toWei(1e18, 18), 1e18);
        assertEq(TokenLibrary.toWei(5e17, 18), 5e17);

        // 0 decimals to 18 decimals
        assertEq(TokenLibrary.toWei(1, 0), 1e18);
        assertEq(TokenLibrary.toWei(5, 0), 5e18);

        // 20 decimals to 18 decimals
        assertEq(TokenLibrary.toWei(1e20, 20), 1e18);
    }

    function testFromWei() public pure {
        // 18 decimals to 0 decimals
        assertEq(TokenLibrary.fromWei(1e18, 0), 1);

        // 18 decimals to 6 decimals
        assertEq(TokenLibrary.fromWei(1e18, 6), 1e6);
        assertEq(TokenLibrary.fromWei(5e17, 6), 5e5);

        // 18 decimals to 8 decimals
        assertEq(TokenLibrary.fromWei(1e18, 8), 1e8);
        assertEq(TokenLibrary.fromWei(5e17, 8), 5e7);

        // 18 decimals to 18 decimals (no change)
        assertEq(TokenLibrary.fromWei(1e18, 18), 1e18);
        assertEq(TokenLibrary.fromWei(5e17, 18), 5e17);

        // 18 decimals to 0 decimals
        assertEq(TokenLibrary.fromWei(1e18, 0), 1);
        assertEq(TokenLibrary.fromWei(5e18, 0), 5);

        // 18 decimals to 20 decimals
        assertEq(TokenLibrary.fromWei(1e18, 20), 1e20);
    }

    function testConvertDecimals() public pure {
        // 6 decimals to 8 decimals
        assertEq(TokenLibrary.convertDecimals(1e6, 6, 8), 1e8);

        // 8 decimals to 6 decimals
        assertEq(TokenLibrary.convertDecimals(1e8, 8, 6), 1e6);

        // 6 decimals to 18 decimals
        assertEq(TokenLibrary.convertDecimals(1e6, 6, 18), 1e18);

        // 18 decimals to 6 decimals
        assertEq(TokenLibrary.convertDecimals(1e18, 18, 6), 1e6);

        // Same decimals (no change)
        assertEq(TokenLibrary.convertDecimals(1e6, 6, 6), 1e6);
        assertEq(TokenLibrary.convertDecimals(1e18, 18, 18), 1e18);

        // Test precision for small numbers
        assertEq(TokenLibrary.convertDecimals(1, 0, 18), 1e18);
        assertEq(TokenLibrary.convertDecimals(1e18, 18, 0), 1);

        // Test precision for large numbers
        assertEq(TokenLibrary.convertDecimals(1e30, 30, 18), 1e18);
        assertEq(TokenLibrary.convertDecimals(1e18, 18, 30), 1e30);
    }

    function testEdgeCases() public pure {
        // Very large numbers
        assertEq(TokenLibrary.toWei(1e30, 30), 1e18);
        assertEq(TokenLibrary.fromWei(1e18, 30), 1e30);

        // Very small numbers
        assertEq(TokenLibrary.toWei(1, 1), 1e17);
        assertEq(TokenLibrary.fromWei(1, 1), 0);

        // Zero
        assertEq(TokenLibrary.toWei(0, 6), 0);
        assertEq(TokenLibrary.fromWei(0, 6), 0);
        assertEq(TokenLibrary.convertDecimals(0, 6, 18), 0);

        console.log(TokenLibrary.fromWei(28_580_161, 0));
    }

    function testFuzzToWei(uint256 amount, uint8 decimals) public pure {
        vm.assume(decimals <= 18);
        vm.assume(amount <= type(uint256).max / 10 ** 18); // Prevent overflow

        uint256 result = TokenLibrary.toWei(amount, decimals);
        assertEq(result / 10 ** (18 - decimals), amount);
    }

    function testFuzzFromWei(uint256 amount, uint8 decimals) public pure {
        vm.assume(decimals <= 18);

        uint256 result = TokenLibrary.fromWei(amount, decimals);

        if (decimals == 18) {
            assertEq(result, amount);
        } else {
            uint256 divisor = 10 ** (18 - decimals);
            assertEq(result, amount / divisor);
        }
    }

    function testFuzzConvertDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) public pure {
        vm.assume(fromDecimals <= 77 && toDecimals <= 77);
        vm.assume(amount <= type(uint256).max / 10 ** 77); // Prevent overflow

        uint256 result = TokenLibrary.convertDecimals(
            amount,
            fromDecimals,
            toDecimals
        );
        if (fromDecimals > toDecimals) {
            assertApproxEqAbs(
                result * 10 ** (fromDecimals - toDecimals),
                amount,
                1
            );
        } else if (fromDecimals < toDecimals) {
            assertEq(result / 10 ** (toDecimals - fromDecimals), amount);
        } else {
            assertEq(result, amount);
        }
    }

    function testConvertDecimalsExtremeCases() public {
        // Test with maximum uint256 value
        uint256 maxUint = type(uint256).max;

        // Converting max uint256 from 0 decimals to 18 decimals (should revert due to overflow)
        vm.expectRevert();
        TokenLibrary.convertDecimals(maxUint, 0, 18);

        // Converting max uint256 from 18 decimals to 0 decimals
        assertEq(TokenLibrary.convertDecimals(maxUint, 18, 0), maxUint / 1e18);

        // Test with very small non-zero value
        uint256 smallValue = 1;

        // Converting 1 from 18 decimals to 0 decimals (should be 0)
        assertEq(TokenLibrary.convertDecimals(smallValue, 18, 0), 0);

        // Converting 1 from 0 decimals to 18 decimals
        assertEq(TokenLibrary.convertDecimals(smallValue, 0, 18), 1e18);
    }
}
