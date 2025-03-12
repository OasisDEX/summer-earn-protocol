// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import "../../src/contracts/arks/MorphoVaultArk.sol";
import "../../src/events/IArkEvents.sol";

import {IArk} from "../../src/interfaces/IArk.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IRaft} from "../../src/interfaces/IRaft.sol";
import {BaseAuctionParameters} from "../../src/types/CommonAuctionTypes.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/DecayFunctions.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract MetaMorphoArkTestFork is Test, IArkEvents, ArkTestBase {
    MorphoVaultArk public ark;

    address public constant METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    address public constant MORPHO_URD_FACTORY =
        0x9baA51245CDD28D8D74Afe8B3959b616E9ee7c8D;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address REWARD_TOKEN = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2;
    address CURATOR = 0xa16f07B4Dd32250DEc69C63eCd0aef6CD6096d3d;
    IERC20 rewardToken = IERC20(REWARD_TOKEN);

    address public usdFleet = 0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17;

    IMetaMorpho public metaMorpho;
    IERC20 public asset;
    IERC20 public usdc;
    uint256 forkBlock = 20376149; // Adjust this to a suitable block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        metaMorpho = IMetaMorpho(METAMORPHO_ADDRESS);
        asset = IERC20(metaMorpho.asset());
        usdc = IERC20(USDC_ADDRESS);
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MorphoVaultArk(
            METAMORPHO_ADDRESS,
            MORPHO_URD_FACTORY,
            params
        );

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Board_MetaMorphoArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        deal(address(asset), commander, amount);

        vm.startPrank(commander);
        asset.approve(address(ark), amount);

        // Expect the deposit call to MetaMorpho
        vm.expectCall(
            METAMORPHO_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.deposit.selector,
                amount,
                address(ark)
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(asset), amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertEq(
            assetsAfterDeposit,
            amount - 1,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual > assetsAfterDeposit,
            "Assets should not decrease after accrual"
        );
    }

    function test_Disembark_MetaMorphoArk_fork() public {
        // First, board some assets
        test_Board_MetaMorphoArk_fork();

        uint256 initialBalance = asset.balanceOf(commander);
        uint256 amountToWithdraw = 500 * 10 ** 6;

        vm.prank(commander);

        // Expect the withdraw call to MetaMorpho
        vm.expectCall(
            METAMORPHO_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.withdraw.selector,
                amountToWithdraw,
                address(ark),
                address(ark)
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(asset), amountToWithdraw);

        ark.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = asset.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = ark.totalAssets();
        assertTrue(
            remainingAssets < 1000 * 10 ** 6,
            "Remaining assets should be less than initial deposit"
        );
    }

    function test_TotalAssets_MetaMorphoArk_fork() public {
        // Deposit some assets first
        test_Board_MetaMorphoArk_fork();

        uint256 initialTotalAssets = ark.totalAssets();

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        uint256 newTotalAssets = ark.totalAssets();

        // Total assets should not decrease over time (assuming no withdrawals)
        assertTrue(
            newTotalAssets > initialTotalAssets,
            "Total assets should increase over time"
        );
    }

    function test_Constructor_MetaMorphoArk_AddressZero_fork() public {
        // Arrange
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: 1000,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Act
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new MorphoVaultArk(address(0), address(0), params);
    }

    function test_Harvest_MetaMorphoArk_RealData_fork() public {
        // Fork at specific block where we know there are rewards
        vm.createSelectFork(vm.rpcUrl("mainnet"), 21975731);

        // Now etch the code at the target address
        address ARK_ADDRESS = 0xf8Db64D39D1c7382fE47De8B72435c7e9DFB2894;
        ark = MorphoVaultArk(ARK_ADDRESS);

        bytes memory harvestData = _getForkTestHarvestData();

        // Call harvest
        vm.prank(address(raft));

        IRaft raftInstance = IRaft(address(ark.raft()));
        uint256 raftUsdcBalanceBefore = rewardToken.balanceOf(
            address(raftInstance)
        );
        vm.prank(0xc2a8467a52Fec8383c424149000cf384de9Ba1B5);
        raftInstance.harvest(ARK_ADDRESS, harvestData);
        uint256 claimable = 500974063498120478273;
        assertEq(
            rewardToken.balanceOf(address(raftInstance)) -
                raftUsdcBalanceBefore,
            claimable,
            "Raft should have received the harvested rewards"
        );
        console.log("harvested (with decimals)   ", claimable);
        console.log("harvested (no     decimals) ", claimable / 1e18);

        BaseAuctionParameters memory newParams = BaseAuctionParameters({
            duration: 2 days,
            startPrice: 4 * 10 ** 6, // 4 USDC (6 decimals)
            endPrice: 1 * 10 ** 6, // 1 USDC (6 decimals)
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(0),
            decayType: DecayFunctions.DecayType.Linear
        });

        // Update auction parameters

        vm.prank(CURATOR);
        raftInstance.setArkAuctionParameters(
            ARK_ADDRESS,
            address(REWARD_TOKEN),
            newParams
        );

        raftInstance.startAuction(ARK_ADDRESS, REWARD_TOKEN);
        assertEq(
            raftInstance.getCurrentPrice(ARK_ADDRESS, REWARD_TOKEN),
            newParams.startPrice
        );

        console.log(
            "price after startAuction (decimals)    ",
            raftInstance.getCurrentPrice(ARK_ADDRESS, REWARD_TOKEN)
        );
        console.log(
            "price after startAuction (no decimals) ",
            raftInstance.getCurrentPrice(ARK_ADDRESS, REWARD_TOKEN) / 1e6
        );

        // buying
        address buyer = address(0x123);
        uint256 amountToBuy = claimable;
        uint256 expectedCost = (amountToBuy * newParams.startPrice + 1) / 1e18;
        console.log("expectedCost", expectedCost);

        deal(USDC_ADDRESS, buyer, expectedCost);

        vm.startPrank(buyer);
        asset.approve(address(raftInstance), amountToBuy);

        uint256 paid = raftInstance.buyTokens(
            ARK_ADDRESS,
            REWARD_TOKEN,
            amountToBuy
        );
        console.log("paid", paid);
        console.log("paid (no decimals)", paid / 1e6);

        assertEq(paid, expectedCost, "Paid should equal expected cost");
    }

    function _getForkTestHarvestData() internal pure returns (bytes memory) {
        // The URD address from the data
        address URD_ADDRESS = 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb;
        address _REWARD_TOKEN = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2;
        address[] memory rewards = new address[](1);
        rewards[0] = _REWARD_TOKEN;

        address[] memory urd = new address[](1);
        urd[0] = URD_ADDRESS;

        uint256[] memory claimable = new uint256[](1);
        claimable[0] = 500974063498120478273; // The exact amount from the data

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](14);
        proofs[0][
            0
        ] = 0xef461f1269cacc9b3530f5a116f436c8e0d9b8a5f0fa44ac147106f660215c99;
        proofs[0][
            1
        ] = 0x52dc3909ab097bc17c9388b7a51c3077245699516ba51c331a94cd234afa9fbc;
        proofs[0][
            2
        ] = 0x96607500982663e0b77101164e00ff753cf3af1045a4146edd462bb041995ccf;
        proofs[0][
            3
        ] = 0x274a7a00d1763643ced8ffe40afff384647989ab756d1a5ea2239bbaada1c533;
        proofs[0][
            4
        ] = 0x7e0ddef4ad96af7a9756504f7977ba4f3504040e6fa210ee86f0347f99301ab1;
        proofs[0][
            5
        ] = 0xfd7ecff79f97fd0cbb8eab1841ceb8d8c10c01b71de8dbaf0854a62f15636a3d;
        proofs[0][
            6
        ] = 0xde0f6b3d6ed0a3a73f10afa548741425822b8ea02f4d7692bac0486e48fb1297;
        proofs[0][
            7
        ] = 0x028f77bc68af63deee298b2511baa477f870f88b381fc572d46c7bdf96c29683;
        proofs[0][
            8
        ] = 0xce98e5d7554baa8cd41697f74e64ecc7c6b6f6b37c002b5d5488c3282a919e6c;
        proofs[0][
            9
        ] = 0x83ac0181628c386ec733f94e4597ee1da0b40eac1aeb26041ae26e8afc21ba03;
        proofs[0][
            10
        ] = 0xec59ff40a4c23098f68f79816d6cf3abe961dcbf375f11571292432cc1c032c6;
        proofs[0][
            11
        ] = 0xa1754165c07e8a1e811ab3d16cf55b1530666a8a133427ca4a1568b529cc0a30;
        proofs[0][
            12
        ] = 0x45016101c944f3c6130a6fabeee2091a8f249a1c6d4689148c457424361d1f63;
        proofs[0][
            13
        ] = 0x91c19181a79a12a2f314be64fa834c5b607a628cd30408dc4d7f2a88638e338b;

        MorphoVaultArk.RewardsData memory rewardsData = MorphoVaultArk
            .RewardsData({
                urd: urd,
                rewards: rewards,
                claimable: claimable,
                proofs: proofs
            });

        return abi.encode(rewardsData);
    }
}
