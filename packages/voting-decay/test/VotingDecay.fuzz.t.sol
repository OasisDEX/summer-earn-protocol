// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {VotingDecayManager} from "../src/VotingDecayManager.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";

// Concrete implementation of VotingDecayManager for testing
contract TestVotingDecayManager is VotingDecayManager {
    constructor(
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        VotingDecayLibrary.DecayFunction decayFunction_
    )
        VotingDecayManager(
            decayFreeWindow_,
            decayRatePerSecond_,
            decayFunction_,
            msg.sender
        )
    {}

    function _getDelegateTo(
        address account
    ) internal pure override returns (address) {
        return account;
    }

    function initializeAccount(address account) public {
        _initializeAccountIfNew(account);
    }

    function resetDecay(address account) public {
        decayInfoByAccount[account] = VotingDecayLibrary.DecayInfo({
            decayFactor: VotingDecayLibrary.WAD,
            lastUpdateTimestamp: uint40(block.timestamp)
        });
    }
}

/**
 * @title VotingDecayFuzzTest
 * @dev Fuzz testing suite for the VotingDecayManager contract
 */
contract VotingDecayFuzzTest is Test {
    TestVotingDecayManager internal decayManager;
    address internal owner = address(0x1);
    address internal user = address(0x2);
    address internal delegate = address(0x3);

    uint256 public constant WAD = 1e18;
    uint256 public constant YEAR_IN_SECONDS = 365 days;
    uint256 public constant MAX_DECAY_RATE = WAD / YEAR_IN_SECONDS; // 100% decay per year

    /**
     * @dev Set up the test environment
     */
    function setUp() public {
        vm.prank(owner);
        decayManager = new TestVotingDecayManager(
            30 days,
            MAX_DECAY_RATE / 10, // 10% decay per year
            VotingDecayLibrary.DecayFunction.Linear
        );
    }

    /**
     * @dev Test decay over time
     * @param elapsedTime Random time period to test decay
     */

    function testFuzz_DecayOverTime(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);
        decayManager.initializeAccount(user);

        uint256 initialFactor = decayManager.getDecayFactor(user);
        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);

        assertLe(finalFactor, initialFactor);
    }

    /**
     * @dev Test value decay
     * @param initialValue Random initial value to test decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_ValueDecay(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);
        vm.warp(block.timestamp + elapsedTime);

        uint256 decayedValue = decayManager.getVotingPower(user, initialValue);
        assertLe(decayedValue, initialValue);
    }

    /**
     * @dev Test setting decay rate
     * @param newRate Random new decay rate to test
     */
    function testFuzz_SetDecayRate(uint256 newRate) public {
        vm.assume(newRate <= MAX_DECAY_RATE);

        vm.prank(owner);
        decayManager.setDecayRatePerSecond(newRate);

        assertEq(decayManager.decayRatePerSecond(), newRate);
    }

    /**
     * @dev Test setting decay-free window
     * @param newWindow Random new decay-free window to test
     */
    function testFuzz_SetDecayFreeWindow(uint40 newWindow) public {
        vm.assume(newWindow <= YEAR_IN_SECONDS);

        vm.prank(owner);
        decayManager.setDecayFreeWindow(newWindow);

        assertEq(decayManager.decayFreeWindow(), newWindow);
    }

    /**
     * @dev Test decay for multiple accounts
     * @param elapsedTimes Array of random time periods to test decay for multiple accounts
     */
    function testFuzz_MultipleAccountsDecay(
        uint256[] memory elapsedTimes
    ) public {
        vm.assume(elapsedTimes.length > 0 && elapsedTimes.length <= 10);

        address[] memory accounts = new address[](elapsedTimes.length);
        uint256[] memory initialFactors = new uint256[](elapsedTimes.length);

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.assume(
                elapsedTimes[i] > 0 && elapsedTimes[i] <= YEAR_IN_SECONDS
            );
            accounts[i] = address(uint160(i + 1));
            decayManager.initializeAccount(accounts[i]);
            initialFactors[i] = decayManager.getDecayFactor(accounts[i]);
        }

        for (uint256 i = 0; i < elapsedTimes.length; i++) {
            vm.warp(block.timestamp + elapsedTimes[i]);
            uint256 finalFactor = decayManager.getDecayFactor(accounts[i]);
            assertLe(finalFactor, initialFactors[i]);
        }
    }

    /**
     * @dev Test resetting decay
     * @param elapsedTime Random time period to test decay reset
     */
    function testFuzz_ResetDecay(uint256 elapsedTime) public {
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);

        uint256 initialFactor = decayManager.getDecayFactor(user);

        // Warp time and update decay
        vm.warp(block.timestamp + elapsedTime);

        uint256 decayedFactor = decayManager.getDecayFactor(user);

        decayManager.resetDecay(user);
        uint256 resetFactor = decayManager.getDecayFactor(user);

        assertEq(
            initialFactor,
            VotingDecayLibrary.WAD,
            "Initial factor should be WAD"
        );
        assertLe(
            decayedFactor,
            initialFactor,
            "Decayed factor should be less than or equal to initial factor"
        );
        assertEq(
            resetFactor,
            VotingDecayLibrary.WAD,
            "Reset factor should be WAD"
        );
        assertGe(
            resetFactor,
            decayedFactor,
            "Reset factor should be greater than or equal to decayed factor"
        );
    }

    /**
     * @dev Test comparison between linear and exponential decay functions
     * @param initialValue Random initial value to test decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_DecayFunctionComparison(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        decayManager.initializeAccount(user);

        // Linear decay
        vm.warp(block.timestamp + elapsedTime);
        uint256 linearDecayedValue = decayManager.getVotingPower(
            user,
            initialValue
        );

        // Reset decay and change to exponential
        decayManager.resetDecay(user);

        vm.prank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );

        // Exponential decay
        vm.warp(block.timestamp + elapsedTime);
        uint256 exponentialDecayedValue = decayManager.getVotingPower(
            user,
            initialValue
        );

        // Exponential decay should result in a higher value than linear decay for the same time period
        assertGe(exponentialDecayedValue, linearDecayedValue);
    }

    /**
     * @dev Test exponential decay
     * @param initialValue Random initial value to test decay
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_ExponentialDecay(
        uint256 initialValue,
        uint256 elapsedTime
    ) public {
        vm.assume(initialValue > 0 && initialValue <= 1e36);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        vm.prank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );

        decayManager.initializeAccount(user);
        uint256 initialFactor = decayManager.getDecayFactor(user);

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);
        uint256 decayedValue = decayManager.getVotingPower(user, initialValue);

        assertLe(
            finalFactor,
            initialFactor,
            "Final factor should be less than or equal to initial factor"
        );
        assertLe(
            decayedValue,
            initialValue,
            "Decayed value should be less than or equal to initial value"
        );
        if (initialValue > 1) {
            assertGt(
                decayedValue,
                0,
                "Decayed value should be greater than zero"
            );
        }
    }

    /**
     * @dev Test exponential decay rate
     * @param decayRate Random decay rate to test
     * @param elapsedTime Random time period to test decay
     */
    function testFuzz_ExponentialDecayRate(
        uint256 decayRate,
        uint256 elapsedTime
    ) public {
        vm.assume(decayRate > 0 && decayRate <= MAX_DECAY_RATE);
        vm.assume(elapsedTime > 0 && elapsedTime <= YEAR_IN_SECONDS);

        vm.startPrank(owner);
        decayManager.setDecayFunction(
            VotingDecayLibrary.DecayFunction.Exponential
        );
        decayManager.setDecayRatePerSecond(decayRate);
        vm.stopPrank();

        decayManager.initializeAccount(user);
        uint256 initialFactor = decayManager.getDecayFactor(user);

        vm.warp(block.timestamp + elapsedTime);
        uint256 finalFactor = decayManager.getDecayFactor(user);

        assertLe(
            finalFactor,
            initialFactor,
            "Final factor should be less than or equal to initial factor"
        );
        assertGt(finalFactor, 0, "Final factor should be greater than zero");
    }
}
