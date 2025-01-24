// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {console} from "forge-std/console.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {VotingDecayMath} from "@summerfi/voting-decay/VotingDecayMath.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract SummerTokenVotingTest is SummerTokenTestBase {
    // State variables
    address[] private actors;
    uint256 constant WAD = Constants.WAD;

    ISummerToken public token;

    function setUp() public virtual override {
        super.setUp();

        token = aSummerToken;

        // Initialize actors array with test addresses
        actors = new address[](5);
        actors[0] = makeAddr("alice");
        actors[1] = makeAddr("bob");
        actors[2] = makeAddr("charlie");
        actors[3] = makeAddr("dave");
        actors[4] = makeAddr("eve");

        // Setup initial conditions for each actor
        for (uint256 i = 0; i < actors.length; i++) {
            // Give each actor some initial tokens
            deal(address(token), actors[i], 1_000_000 * 1e18);

            // Initialize decay factor for each actor
            vm.prank(address(token));
            token.updateDecayFactor(actors[i]);
        }

        enableTransfers();

        vm.prank(address(timelockA));
        token.setDecayRatePerYear(Percentage.wrap(0.1e18));
    }

    // Test function that reproduces the specific failure case from the regression
    function test_regression_invariant_ST_VD5_delegateChangePreservesVotingPower_d83142ff_failure()
        public
    {
        // 2. Set initial block/timestamp
        vm.warp(1711034027);
        vm.roll(19483854);

        // 1. Actor 0x7CbB1e98 (A) delegatesBySig to Actor 0xFF354Cf7 (B)
        // 2. Actor 0xFF354Cf7 (B) delegates to Actor 0x7CbB1e98 (A)
        // 3. Actor 0xFF354Cf7 (B) burns 999,999.999999999999999998 tokens
        // 4. Actor 0xFF354Cf7 (B) delegates to themselves

        // 3. Delegate calls in sequence
        vm.startPrank(actors[0]);
        token.delegate(actors[1]);
        vm.stopPrank();

        vm.startPrank(actors[1]);
        token.delegate(actors[0]);
        vm.stopPrank();

        vm.warp(1711034027);
        vm.roll(19483854);

        vm.startPrank(actors[1]);
        ERC20Burnable(address(token)).burn(999_999 * 1e18);
        vm.stopPrank();

        vm.startPrank(actors[1]);
        token.delegate(actors[1]);
        vm.stopPrank();

        _invariant_ST_VD5_delegateChangePreservesVotingPower();
    }

    function _invariant_ST_VD5_delegateChangePreservesVotingPower() public {
        for (uint256 i = 0; i < actors.length; i++) {
            address account = actors[i];
            if (account == address(0)) {
                continue;
            }

            address currentDelegate = token.delegates(account);
            uint256 beforePowerOld = token.getVotes(currentDelegate);
            uint256 beforePowerNew = token.getVotes(account);

            console.log("currentDelegate: ", currentDelegate);
            console.log("beforePowerOld: ", beforePowerOld);
            console.log("beforePowerNew: ", beforePowerNew);

            // Re-delegate from 'account' to itself
            vm.prank(account);
            token.delegate(account);

            // Retrieve the delegate's updated decay factor
            uint256 delegateDecayFactor = token.getDecayFactor(account);

            // 1) Check that new delegate's votes haven't dropped below the expected decay-based threshold
            require(
                token.getVotes(account) >=
                    VotingDecayMath.mulDiv(
                        beforePowerNew,
                        delegateDecayFactor,
                        WAD
                    ),
                "New delegate power decreased"
            );

            console.log("beforePowerOld: ", beforePowerOld);
            console.log("currentDelegate: ", token.getVotes(currentDelegate));

            // 2) Ensure the old delegate's vote count didn't jump above its prior value
            require(
                token.getVotes(currentDelegate) <= beforePowerOld,
                "Old delegate power increased"
            );
        }
    }
}
