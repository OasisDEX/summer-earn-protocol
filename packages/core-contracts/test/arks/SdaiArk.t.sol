// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../../src/contracts/arks/SDAIArk.sol";
import {ArkParams} from "../../src/interfaces/IArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";

contract SDAIArkTest is Test {
    SDAIArk public ark;
    IERC20 public dai;
    IERC4626 public sDAI;
    IPot public pot;

    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant SDAI_ADDRESS =
        0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant POT_ADDRESS =
        0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;

    address public constant WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503; // Dai whale address

    function setUp() public {
        vm.createSelectFork("mainnet", 20622619); // Replace with a recent block number

        dai = IERC20(DAI_ADDRESS);
        sDAI = IERC4626(SDAI_ADDRESS);
        pot = IPot(POT_ADDRESS);

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: DAI_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            name: "SDAI Ark"
        });

        ark = new SDAIArk(SDAI_ADDRESS, POT_ADDRESS, params);
        vm.prank(governor);
        ark.grantCommanderRole(commander);
        // Fund the ark with some DAI
        vm.prank(commander);
        IERC20(DAI_ADDRESS).approve(address(ark), type(uint256).max);
        deal(DAI_ADDRESS, commander, 1000000e18);
    }

    function testRate() public view {
        uint256 arkRate = ark.rate();
        console.log("Ark rate: ", arkRate);
        console.log("Pot DSR: ", arkRate / 1e18);
        uint256 potDsr = pot.dsr();
        uint256 expectedRate = (potDsr - 1e27) * 365 days;
        assertEq(arkRate, expectedRate, "Rate should match the DSR APY");
    }

    function testTotalAssets() public {
        uint256 initialBalance = dai.balanceOf(address(commander));
        vm.prank(commander);
        ark.board(initialBalance);

        // Wait for some time to accrue interest
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 100);

        uint256 totalAssets = ark.totalAssets();
        assertGt(
            totalAssets,
            initialBalance,
            "Total assets should increase due to interest"
        );
    }

    function testBoardAndDisembark() public {
        uint256 initialBalance = dai.balanceOf(address(commander));
        console.log("Initial balance: ", initialBalance);
        vm.prank(commander);
        ark.board(initialBalance);

        assertEq(dai.balanceOf(address(ark)), 0, "All DAI should be deposited");
        assertGt(
            sDAI.balanceOf(address(ark)),
            0,
            "Ark should have sDAI balance"
        );

        // Wait for some time to accrue interest
        vm.warp(block.timestamp + 30 days);

        uint256 totalAssets = ark.totalAssets();
        vm.prank(commander);
        ark.disembark(totalAssets);

        assertEq(
            sDAI.balanceOf(address(ark)),
            0,
            "All sDAI should be withdrawn"
        );
    }

    function testHarvest() public {
        // Harvest should return 0 as SDAI automatically accrues interest
        assertEq(ark.harvest(address(0), ""), 0, "Harvest should return 0");
    }
}
