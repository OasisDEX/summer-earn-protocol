// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FluidFTokenArk} from "../../src/contracts/arks/FluidFTokenArk.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {MockFluidMerkleDistributor} from "../mocks/MockFluidMerkleDistributor.sol";

contract FluidFTokenArkUnitTest is ArkTestBase, IArkEvents {
    using SafeERC20 for IERC20;

    FluidFTokenArk public ark;
    IERC4626 public vault;
    ERC20Mock public assetToken;
    ArkParams public params;

    function setUp() public {
        initializeCoreContracts();

        assetToken = new ERC20Mock();
        vault = IERC4626(address(new ERC4626Mock(address(assetToken))));

        params = ArkParams({
            name: "Fluid fToken Ark",
            details: "Fluid fToken Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(assetToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new FluidFTokenArk(address(vault), params);

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor_RevertOnZeroVault() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new FluidFTokenArk(address(0), params);
    }

    function test_Constructor_RevertOnAssetMismatch() public {
        ERC20Mock otherAsset = new ERC20Mock();
        IERC4626 badVault = IERC4626(
            address(new ERC4626Mock(address(otherAsset)))
        );
        vm.expectRevert(abi.encodeWithSignature("ERC4626AssetMismatch()"));
        new FluidFTokenArk(address(badVault), params);
    }

    function test_Harvest_HappyPath_MintsAndForwardsToRaft() public {
        uint256 rewardAmount = 1_000e18;
        // Arrange: setup distributor and reward token
        ERC20Mock reward = new ERC20Mock();
        MockFluidMerkleDistributor distributor = new MockFluidMerkleDistributor(
            address(reward)
        );
        deal(address(reward), address(distributor), rewardAmount);
        FluidFTokenArk.ClaimData memory claimData = FluidFTokenArk.ClaimData({
            merkleClaimer: address(distributor),
            recipient: address(ark),
            cumulativeAmount: rewardAmount,
            positionType: 1,
            positionId: bytes32(uint256(1)),
            cycle: 1,
            merkleProof: new bytes32[](0),
            metadata: bytes("")
        });

        uint256 raftBalBefore = reward.balanceOf(raft);

        // Act: call harvest as raft
        vm.prank(raft);
        (address[] memory tokens, uint256[] memory amounts) = ark.harvest(
            abi.encode(claimData)
        );

        // Assert
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(reward));
        assertEq(amounts.length, 1);
        assertEq(reward.balanceOf(raft) - raftBalBefore, rewardAmount);
    }

    function test_Harvest_ZeroMint_Ok() public {
        ERC20Mock reward = new ERC20Mock();
        MockFluidMerkleDistributor distributor = new MockFluidMerkleDistributor(
            address(reward)
        );
        deal(address(reward), address(distributor), 0);
        FluidFTokenArk.ClaimData memory claimData = FluidFTokenArk.ClaimData({
            merkleClaimer: address(distributor),
            recipient: address(ark),
            cumulativeAmount: 0,
            positionType: 1,
            positionId: bytes32(uint256(1)),
            cycle: 1,
            merkleProof: new bytes32[](0),
            metadata: bytes("")
        });

        vm.prank(raft);
        (address[] memory tokens, uint256[] memory amounts) = ark.harvest(
            abi.encode(claimData)
        );
        assertEq(tokens[0], address(reward));
        assertEq(amounts[0], 0);
    }

    function test_Harvest_Revert_InvalidRecipient() public {
        uint256 rewardAmount = 1_000e18;
        ERC20Mock reward = new ERC20Mock();
        MockFluidMerkleDistributor distributor = new MockFluidMerkleDistributor(
            address(reward)
        );
        deal(address(reward), address(distributor), rewardAmount);
        FluidFTokenArk.ClaimData memory claimData = FluidFTokenArk.ClaimData({
            merkleClaimer: address(distributor),
            recipient: address(commander), // wrong recipient
            cumulativeAmount: rewardAmount,
            positionType: 1,
            positionId: bytes32(uint256(1)),
            cycle: 1,
            merkleProof: new bytes32[](0),
            metadata: bytes("")
        });

        vm.expectRevert();
        vm.prank(raft);
        ark.harvest(abi.encode(claimData));
    }

    function test_Harvest_Revert_InvalidClaimer() public {
        uint256 rewardAmount = 1_000e18;
        FluidFTokenArk.ClaimData memory claimData = FluidFTokenArk.ClaimData({
            merkleClaimer: address(0),
            recipient: address(ark),
            cumulativeAmount: rewardAmount,
            positionType: 1,
            positionId: bytes32(uint256(1)),
            cycle: 1,
            merkleProof: new bytes32[](0),
            metadata: bytes("")
        });

        vm.expectRevert();
        vm.prank(raft);
        ark.harvest(abi.encode(claimData));
    }

    function test_Harvest_Revert_ZeroRewardToken() public {
        uint256 rewardAmount = 1_000e18;
        // Distributor with zero token address
        MockFluidMerkleDistributor distributor = new MockFluidMerkleDistributor(
            address(0)
        );
        FluidFTokenArk.ClaimData memory claimData = FluidFTokenArk.ClaimData({
            merkleClaimer: address(distributor),
            recipient: address(ark),
            cumulativeAmount: rewardAmount,
            positionType: 1,
            positionId: bytes32(uint256(1)),
            cycle: 1,
            merkleProof: new bytes32[](0),
            metadata: bytes("")
        });

        vm.expectRevert();
        vm.prank(raft);
        ark.harvest(abi.encode(claimData));
    }
}
