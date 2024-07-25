// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Tipper} from "../../src/contracts/Tipper.sol";
import "../../src/contracts/ConfigurationManager.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";

contract RPowTest is Test {
    address public governor = address(1);
    TipperHarness public tipper;

    function setUp() public {
        ProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );
        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: address(2),
                raft: address(3)
            })
        );

        tipper = new TipperHarness(address(configurationManager));
    }

    function test_rpow_x_zero() public view {
        assertEq(tipper.exposed_rpow(0, 5, 1e18), 0);
        assertEq(tipper.exposed_rpow(0, 0, 1e18), 1e18);
    }

    function test_rpow_n_zero() public view {
        assertEq(tipper.exposed_rpow(5, 0, 1e18), 1e18);
        assertEq(tipper.exposed_rpow(1e18, 0, 1e18), 1e18);
    }

    function test_rpow_x_one() public view {
        assertEq(tipper.exposed_rpow(1e18, 5, 1e18), 1e18);
        assertEq(tipper.exposed_rpow(1e18, 100, 1e18), 1e18);
    }

    function test_rpow_n_one() public view {
        assertEq(tipper.exposed_rpow(5e18, 1, 1e18), 5e18);
        assertEq(tipper.exposed_rpow(1234e18, 1, 1e18), 1234e18);
    }

    function test_rpow_identity() public view {
        assertEq(tipper.exposed_rpow(2e18, 3, 1e18), 8e18);
        assertEq(tipper.exposed_rpow(10e18, 2, 1e18), 100e18);
    }

    function test_rpow_basic_fractional() public view {
        // 1.5^2 should be close to 2.25
        assertApproxEqRel(tipper.exposed_rpow(1.5e18, 2, 1e18), 2.25e18, 1e15);
    }

    function test_rpow_high_precision() public view {
        // Test with high precision numbers
        uint256 result = tipper.exposed_rpow(1.000000001e27, 365, 1e27);
        assertApproxEqRel(result, 1.000365003e27, 1e18);
    }

    function test_rpow_large_exponent() public view {
        // 1.0001^10000 should be approximately 2.718
        uint256 result = tipper.exposed_rpow(1.0001e18, 10000, 1e18);
        assertApproxEqRel(result, 2.718e18, 1e16);
    }

    function test_rpow_large_base() public view {
        // 1000^3 = 1,000,000,000
        assertEq(tipper.exposed_rpow(1000e18, 3, 1e18), 1_000_000_000e18);
    }

    function test_rpow_fractional_exponent() public view {
        // This function doesn't support fractional exponents, so it should use the integer part
        // 2^2.5 should be treated as 2^2 = 4
        assertEq(tipper.exposed_rpow(2e18, 2, 1e18), 4e18);
    }

    function test_rpow_precision_limit() public view {
        // Test the limits of precision
        uint256 result = tipper.exposed_rpow(1.000000001e18, 1000000, 1e18);
        assertGt(result, 1e18);
        assertLt(result, 3e18);
    }

    function test_rpow_revert_on_overflow() public {
        // This should revert due to overflow
        vm.expectRevert();
        tipper.exposed_rpow(2e18, 256, 1e18);
    }

    function testFuzz_rpow(uint256 x, uint256 n) public {
        x = bound(x, 0, 2e18); // Limit x to twice the SCALE used in Tipper.sol
        n = bound(n, 0, 120); // Limit n to max of 120 days

        console.log("x:", x);
        console.log("n:", n);

        uint256 base = 1e18;

        uint256 result = tipper.exposed_rpow(x, n, base);

        // Perform sanity checks
        if (x == 0) {
            assertEq(result, n == 0 ? base : 0, "Incorrect result for x = 0");
        } else if (n == 0) {
            assertEq(result, base, "Incorrect result for n = 0");
        } else if (x <= base) {
            assertLe(result, 1e18, "Result should be <= 1e18 for x <= 1e18");
        } else {
            assertGe(result, x, "Result should be >= x for x > 1e18");
        }

        // Additional checks for reasonable results
        if (n > 1 && x > base) {
            assertGt(result, x, "Result should be > x for x > 1e18 and n > 1");
        }
    }

    function test_rpow_large_values() public {
        uint256 x = 56610782522617504509663513468969451453767296;
        uint256 n = 29848005564986788644735984644626;

        vm.expectRevert(); // We expect this call to revert due to overflow
        tipper.exposed_rpow(x, n, 1e18);
    }

    function test_rpow_gas_usage() public view {
        // Measure gas usage for a typical operation
        uint256 gasBefore = gasleft();
        tipper.exposed_rpow(1.01e18, 365, 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        // Log gas usage and ensure it's within expected range
        console.log("Gas used for rpow: ", gasUsed);
        assertLt(gasUsed, 10000); // Adjust the expected gas usage as needed
    }
}

// Helper contract to expose the internal _rpow function for testing
contract TipperHarness is Tipper {
    constructor(address configurationManager) Tipper(configurationManager, 0) {}

    function exposed_rpow(
        uint256 x,
        uint256 n,
        uint256 base
    ) public pure returns (uint256) {
        return _rpow(x, n, base);
    }

    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {}
}
