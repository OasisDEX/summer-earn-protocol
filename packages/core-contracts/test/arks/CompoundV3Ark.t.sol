// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/CompoundV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ICometRewards} from "../../src/interfaces/compound-v3/ICometRewards.sol";

contract CompoundV3ArkTest is Test, IArkEvents {
    CompoundV3Ark public ark;
    IProtocolAccessManager accessManager;
    IConfigurationManager configurationManager;
    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    address public constant cometAddress =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant cometRewards = address(5);

    IComet public comet;
    ERC20Mock public mockToken;

    function setUp() public {
        mockToken = new ERC20Mock();
        comet = IComet(cometAddress);

        accessManager = new ProtocolAccessManager(governor);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });
        ark = new CompoundV3Ark(address(comet), cometRewards, params);

        // Permissioning
        vm.prank(governor);
        ark.grantCommanderRole(commander);
    }

    function test_Constructor() public {
        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });
        ark = new CompoundV3Ark(address(comet), cometRewards, params);
        assertEq(address(ark.comet()), address(comet));
        assertEq(address(ark.token()), address(mockToken));
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
        ark.board(amount);
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
        ark.disembark(amount);
    }

    function test_Harvest() public {
        address mockRewardToken = address(10);
        uint256 mockClaimedRewardsBalance = 1000 * 10 ** 18;

        // Mock the call to claim
        vm.mockCall(
            address(cometRewards),
            abi.encodeWithSelector(
                ICometRewards(cometRewards).claim.selector,
                address(comet),
                address(ark),
                true
            ),
            abi.encode()
        );

        // Mock the balance of reward token after claiming
        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(
                IERC20(mockRewardToken).balanceOf.selector,
                address(ark)
            ),
            abi.encode(mockClaimedRewardsBalance)
        );

        // Mock the transfer of reward token to raft
        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                raft,
                mockClaimedRewardsBalance
            ),
            abi.encode(true)
        );

        // Expect the Harvested event to be emitted
        vm.expectEmit(false, false, false, true);
        emit Harvested(mockClaimedRewardsBalance);

        // Act
        uint256 harvestedAmount = ark.harvest(mockRewardToken, bytes(""));

        // Assert
        assertEq(
            harvestedAmount,
            mockClaimedRewardsBalance,
            "Harvested amount should match mocked balance"
        );
    }
}
