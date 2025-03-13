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
    address public USDC_ADDRESS_BASE =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address REWARD_TOKEN = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842;
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
        vm.createSelectFork(vm.rpcUrl("base"), 27199730);

        address ARK_ADDRESS = 0x165D1accC5C6326e7EE4deeF75Ac3ffC8ce4D79B;
        address KEEPER = 0xc2a8467a52Fec8383c424149000cf384de9Ba1B5;
        usdc = IERC20(USDC_ADDRESS_BASE);
        asset = IERC20(USDC_ADDRESS_BASE);
        ark = MorphoVaultArk(ARK_ADDRESS);

        // params taken from the already deployed ark
        ArkParams memory params = ArkParams({
            name: "OnchainArk",
            details: "OnchainArk details",
            accessManager: 0xf389BCEa078acD9516414F5dabE3dDd5f7e39694,
            configurationManager: 0x8ae7fbAeCfBDb21c28b1854272BB7A3a813e2A66,
            asset: address(asset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        MorphoVaultArk modifiedArk = new MorphoVaultArk(
            0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61,
            0x7276454fc1cf9C408deeed722fd6b5E7A4CA25D8,
            params
        );
        // we need to etch the code at the target address and make it persistent (after fork roll)
        vm.etch(ARK_ADDRESS, address(modifiedArk).code);
        vm.makePersistent(ARK_ADDRESS);

        vm.prank(address(raft));

        IRaft raftInstance = IRaft(address(ark.raft()));
        uint256 raftUsdcBalanceBefore = rewardToken.balanceOf(
            address(raftInstance)
        );
        // claimData taken from the already deployed ark
        bytes
            memory claimData = hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000010000000000000000000000005400dbb270c956e8985184335a1c62aca6ce13330000000000000000000000000000000000000000000000000000000000000001000000000000000000000000baa5cc21fd487b8fcc2f632f3f4e8d37262a08420000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000003e8585846bb84f663000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000011b2dad367fe730f0258f7aed1493cbdbd4859ff8fe0f5b1692b778e7d9f02cebe137d0f6c2742e2b70c922c1f3db064822caa8a65292377c8e9696edb84087c35a2274692ef25fe4ff0612ef836a261a6bcd743e2c6bf637d984da8f3144ebfdb3e0dd37a5b4a2fe555997e278a2eade8c0e9967aac5bca962f6fbc0d63dcfead99688c3871fc3c8425b8fa6bd35d10060e25abfe26657c55f206e1155232a35c97587e06cdf437b8b0e735d0ca69a63a38df5ff322aecf126101dde8d22ada08c8286ad50fafa0d0accb9fdeeba68709aa9b8cf8a2cf6163973e703ba8eec2cde3b408604ddaddcf672ce9f12299ffd4719994ba15e002b5965973ad4f0e6402ce4d8d84eff1939dfc87bcd837e522a9d9a8ad0a5cb969d65a3b9aac61cbcaf3a7c8f50901fbcfd07b2373c78c983744c818663916ed1b1db0a1b79df9a4d26b985e18978a9e2cbd963c2560413962a4cc97fe187129a7e24a2a09c5feacd713869d931b5a0a05093f5c48c6bdb01799af1f4a71cceea8317534db4b16c925398a49edd6975437c1a357810ebd578fc3b9febb8a903d89ebf3ae661571083579ae8f5dd9a89bcc79af2cacd72152b51e69a7e33adab57321c458a1a3f873c0b67e3ccf5212061ad907d28d0727fb23516f4fbdf58d0eb6681b77a0cda5ffc20e5bd637f62588af7878bcff06ce35e0b7b9e262dda80699068ef49fdfb8eb90daa1f2e7703be4c88a8191d3453245bc0b04ebaa3195ee84eeb25957789ac0ac8f";

        vm.prank(KEEPER);
        raftInstance.harvest(ARK_ADDRESS, claimData);
        uint256 claimable = 72082460896695481955;
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

        deal(USDC_ADDRESS_BASE, buyer, expectedCost);

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

        vm.stopPrank();

        vm.rollFork(27542291);

        bytes memory claimDataNew = _getForkTestHarvestData();
        vm.prank(KEEPER);
        raftInstance.harvest(ARK_ADDRESS, claimDataNew);
    }

    function _getForkTestHarvestData() internal pure returns (bytes memory) {
        // The URD address from the data
        address URD_ADDRESS = 0x5400dBb270c956E8985184335A1C62AcA6Ce1333;
        address _REWARD_TOKEN = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842;
        address[] memory rewards = new address[](1);
        rewards[0] = _REWARD_TOKEN;

        address[] memory urd = new address[](1);
        urd[0] = URD_ADDRESS;

        uint256[] memory claimable = new uint256[](1);
        claimable[0] = 83016174938586317674; // The exact amount from the data

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](17);

        proofs[0][
            0
        ] = 0xc9081d20cf67defacde5cefdbbabfa4cf48d4cfc5939e6fbdcaefaa692d45407;
        proofs[0][
            1
        ] = 0x3c57ec25369aaa0e3038748f4502841db582e4a484e133668e68107c92738045;
        proofs[0][
            2
        ] = 0x0d3b3d4b87e87654bafbcbd609c19acf894616c7350c339e537a81afbe56ded8;
        proofs[0][
            3
        ] = 0xc00551acc2600509c5fb273e7c49ea6c1bc84852c8598ff438a2af278d643693;
        proofs[0][
            4
        ] = 0xa10e4926b61924831e77f1255e3ec32fd8b9b544a0efc275247478bfc3a67b3e;
        proofs[0][
            5
        ] = 0xa26141df2c2430731ba6c36b5ca048d22e71840ac40468c0d30d6b5fc305858f;
        proofs[0][
            6
        ] = 0x2d8664311dd17a127ed9a1b892d5dc07f5d1ed44462f19501ff25effebc23ca7;
        proofs[0][
            7
        ] = 0xfedd2c4fd9563a3ca974c11bd4a203227fb105098849c9118a7b971ee078305a;
        proofs[0][
            8
        ] = 0xea5cbe7ca6572cbeb0fe42b729c4a3619164dd19d0bbaab5132d68da30312f25;
        proofs[0][
            9
        ] = 0x7b8803ae30f41ba5c75d9dcf50c5d536764c241819fe5bfc09e5000a5d402956;
        proofs[0][
            10
        ] = 0x1f8d7b231e77c93546c8ba71ade45efd64967abc0d4dd8bdd4ae86b48faba01d;
        proofs[0][
            11
        ] = 0x4bad5e2b608e8b3f19bced4d9df66fa3f646f1cdcf64a731633ba9bb587d1b82;
        proofs[0][
            12
        ] = 0xb107d4554fa533ca2468b2d5f98076485b600198348e5ea2304c11fb386aba9b;
        proofs[0][
            13
        ] = 0x9b9e4c6cecb9b18744ac9c60ca3a28f5514c65442a7cc9e51f86b0970dd12f2d;
        proofs[0][
            14
        ] = 0x9cf5368612dcffe7374f0aa1430d0096314bd6c688ca6bbfcde38b8aa810a056;
        proofs[0][
            15
        ] = 0x6452c946e34d54d19d26a3d5c40d4eb88f3ae9f65e56f1a51195f03bcf63b400;
        proofs[0][
            16
        ] = 0x37476f7d0da4d1bc8dbe92eacddf4b8182815ce83201b2634964b4f32d9d80ac;

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
