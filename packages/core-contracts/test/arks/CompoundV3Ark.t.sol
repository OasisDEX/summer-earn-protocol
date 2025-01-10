// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/CompoundV3Ark.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import "../../src/events/IArkEvents.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract CompoundV3ArkTest is Test, IArkEvents, ArkTestBase {
    CompoundV3Ark public ark;

    address public constant cometAddress =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant cometRewards = address(5);

    IComet public comet;

    function setUp() public {
        initializeCoreContracts();
        comet = IComet(cometAddress);
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        ark = new CompoundV3Ark(address(comet), cometRewards, params);

        // Permissioning
        vm.prank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        ark = new CompoundV3Ark(address(comet), cometRewards, params);
        assertEq(address(ark.comet()), address(comet));
        assertEq(address(ark.asset()), address(mockToken));
        assertEq(ark.depositCap(), type(uint256).max);
    }

    function test_Board() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);

        vm.mockCall(
            address(comet),
            abi.encodeWithSelector(
                comet.supply.selector,
                address(mockToken),
                amount
            ),
            abi.encode()
        );

        vm.expectCall(
            address(comet),
            abi.encodeWithSelector(
                comet.supply.selector,
                address(mockToken),
                amount
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));
    }

    function test_Disembark() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            address(comet),
            abi.encodeWithSelector(
                comet.withdraw.selector,
                address(mockToken),
                amount
            ),
            abi.encode(amount)
        );

        vm.expectCall(
            address(comet),
            abi.encodeWithSelector(
                comet.withdraw.selector,
                address(mockToken),
                amount
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.disembark(amount, bytes(""));
    }

    function test_Harvest() public {
        address mockRewardToken = address(10);
        uint256 mockClaimedRewardsBalance = 1000 * 10 ** 18;

        // Mock the rewardConfig call
        vm.mockCall(
            address(cometRewards),
            abi.encodeWithSelector(
                ICometRewards.rewardConfig.selector,
                address(comet)
            ),
            abi.encode(
                ICometRewards.RewardConfig({
                    token: mockRewardToken,
                    rescaleFactor: 0,
                    shouldUpscale: false
                })
            )
        );

        // Mock the claimTo call instead of claim
        vm.mockCall(
            address(cometRewards),
            abi.encodeWithSelector(
                ICometRewards.claimTo.selector,
                address(comet),
                address(ark),
                address(raft),
                true
            ),
            abi.encode()
        );

        // Mock the balance of reward token after claiming
        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(raft)),
            abi.encode(mockClaimedRewardsBalance)
        );

        // Expect the Harvested event to be emitted
        vm.expectEmit(false, false, false, true);
        address[] memory rewardTokens = new address[](1);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardTokens[0] = mockRewardToken;
        rewardAmounts[0] = mockClaimedRewardsBalance;

        emit ArkHarvested(rewardTokens, rewardAmounts);

        // Act
        vm.prank(address(raft));
        ark.harvest("");

        // Assert
        assertEq(
            rewardAmounts[0],
            mockClaimedRewardsBalance,
            "Harvested amount should match mocked balance"
        );
    }
}
