// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {SummerVestingWalletsEscrow} from "../../src/contracts/SummerVestingWalletsEscrow.sol";

contract SummerVestingWalletsEscrowTestBase is SummerGovernorV2TestBase {
    // address public user1 = address(0x1001);
    // address public user2 = address(0x1002);
    uint256 public constant STAKE_AMOUNT = 1000 ether;

    SummerVestingWalletsEscrow public aStaking;
    SummerVestingWalletsEscrow public bStaking;

    function setUp() public virtual override {
        super.setUp();

        address[] memory emptyVestingFactories = new address[](0);
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        aStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );
        bStaking = new SummerVestingWalletsEscrow(
            address(accessManagerB),
            address(bSummerToken),
            address(bxSumr),
            emptyVestingFactories
        );
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(aStaking));
        vm.prank(address(timelockB));
        bxSumr.addStakingModule(address(bStaking));
    }
    // Helper function to create a fresh staking contract for isolated tests
    function createFreshStaking()
        internal
        returns (SummerVestingWalletsEscrow)
    {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        SummerVestingWalletsEscrow freshStaking = new SummerVestingWalletsEscrow(
                address(accessManagerA),
                address(aSummerToken),
                address(axSumr),
                vestingFactories
            );

        // Set staking module so freshStaking can mint/burn StakedSummerToken
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(freshStaking));

        return freshStaking;
    }
}
