// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "../../src/contracts/arks/PendlePTArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {PERCENTAGE_100, Percentage, PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {PendlePtArkConstructorParams} from "../../src/contracts/arks/PendlePTArk.sol";

import {CurveSwapPendlePtArk} from "../../src/contracts/arks/CurveSwapArk.sol";
import {LimitOrderData, TokenInput, TokenOutput} from "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {SwapData, SwapType} from "@pendle/core-v2/contracts/router/swap-aggregator/IPSwapAggregator.sol";
import {ApproxParams} from "@pendle/core-v2/contracts/router/base/MarketApproxLib.sol";

    struct BoardData {
        bytes swapForPtParams;
    }

    struct DisembarkData {
        bytes swapPtForTokenParams;
    }


contract PendlePTArkTestFork is Test, IArkEvents, ArkTestBase {
    CurveSwapPendlePtArk public ark;

    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant MARKET = 0xcDd26Eb5EB2Ce0f203a84553853667aE69Ca29Ce;
    address constant NEXT_MARKET = 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
    uint256 constant MARKET_EXPIRY_BLOCK = 20379839;
    address constant SY = 0x3Ee118EFC826d30A29645eAf3b2EaaC9E8320185;
    address constant PT = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address constant YT = 0x96512230bF0Fa4E20Cf02C3e8A7d983132cd2b9F;
    address constant PENDLE = 0x808507121B80c02388fAd14726482e061B8da827;
    address constant ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address constant ORACLE = 0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2;
    address constant CURVE_POOL = 0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72;

    IERC20 public usde;
    IPMarketV3 public pendleMarket;
    IPAllActionV3 public pendleRouter;

    uint256 forkBlock = 20927962;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usde = IERC20(USDE);
        pendleMarket = IPMarketV3(MARKET);
        pendleRouter = IPAllActionV3(ROUTER);

        ArkParams memory params = ArkParams({
            name: "Pendle USDE PT Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true
        });

        PendlePtArkConstructorParams
            memory pendlePtArkConstructorParams = PendlePtArkConstructorParams({
                market: MARKET,
                oracle: ORACLE,
                router: ROUTER
            });
        CurveSwapPendlePtArk.CurveSwapArkConstructorParams
            memory curveSwapArkConstructorParams = CurveSwapPendlePtArk.CurveSwapArkConstructorParams({
                curvePool: CURVE_POOL,
                marketAsset: SUSDE
            });
        ark = new CurveSwapPendlePtArk(
            params,
            pendlePtArkConstructorParams,
            curveSwapArkConstructorParams
        );

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), commander);
        vm.stopPrank();

        vm.label(USDE, "USDE");
        vm.label(MARKET, "MARKET");
        vm.label(NEXT_MARKET, "NEXT_MARKET");
        vm.label(SY, "SY");
        vm.label(PT, "PT");
        vm.label(YT, "YT");
        vm.label(PENDLE, "PENDLE");
        vm.label(ROUTER, "ROUTER");
        vm.label(ORACLE, "ORACLE");

        vm.makePersistent(address(ark));
        vm.makePersistent(address(accessManager));
        vm.makePersistent(address(configurationManager));
        vm.makePersistent(USDE);
        vm.makePersistent(MARKET);
        vm.makePersistent(SY);
        vm.makePersistent(PT);
    }

    function test_XXXX() public {
        ApproxParams memory approxParams = ApproxParams({
            guessMin: 77612911885885950133774,
            guessMax: 1112889517632128458326867,
            guessOffchain: 155225823771771900267549,
            maxIteration: 30,
            eps: 10000000000000
        });

        BoardData memory boardData = BoardData({
            swapForPtParams: hex'c81f847a000000000000000000000000aab08ab98c93696665454b8c0a6ef8c2cd0206ef000000000000000000000000281fe15fd3e08a282f52d5cf09a4d13c3709e66d0000000000000000000000000000000000000000000000000debee1ea0e6e76f0000000000000000000000000000000000000000000000000707f6f8323bbab40000000000000000000000000000000000000000000000000ec3ed09364a3b470000000000000000000000000000000000000000000000000e0fedf064777569000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000009184e72a00000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000920000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc800000000000000000000000000000000000000000000000000000000000f42400000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef340000000000000000000000000cc097ac029a7541c4e894c789c7aaa2a9794a2900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000006131b5fae19ea4f9d964eac0408e4408b66337b5000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000684e21fd0e9000000000000000000000000000000000000000000000000000000000000002000000000000000000000000011ddd59c33c73c44733b4123a86ea5ce57f6e854000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000f501020000003f000000dc26dce70f2019aba1da3b35bf36f2dfd03e771efd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb902000000000000000000000000000f42400007c01a0000001a02000000fa4971dc5ad81b4fccaffad0a584d13192b7d2ba01010aff970a61a04b1ca14834a43f5de4533ebddb5cc85d3a1ff2b6bab83b63cd9ad0787074081a52ef34888888888889758f76e7103c6cbf23abbf58f9460000000000000000000000007fffffff0000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e95964220c00000000000000000de8a040288868d80000000000000000000000000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc80000000000000000000000005d3a1ff2b6bab83b63cd9ad0787074081a52ef34000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000888888888889758f76e7103c6cbf23abbf58f94600000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000dc5050c511667cb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000100000000000000000000000011ddd59c33c73c44733b4123a86ea5ce57f6e854000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022e7b22536f75726365223a2250656e646c65222c22416d6f756e74496e555344223a22302e39393934313336393535343530373833222c22416d6f756e744f7574555344223a22312e3030303435313632323335353734222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a2231303032323237313134353038333134383430222c2254696d657374616d70223a313732383536353939372c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a224e5278757030345151356b5869385a626c6837697433706954327574574461446b4e6547386566746463764d61553975696439657451762b384950563774394e31746b55694b4e7643696a47704e3478485474356974576f7476494e5130663150786771334c43717957387174544b3678684b6b687053674971695471614b50523834596e56392f6739347666776c464c666755716a4f52616f784733384d66447533392b58632f534f446d43583473376d6f7661506843436867784f73554a39383050356f44334d3357474e38316a4636353532725930415261364d4d464a466f58424339596c6d4d4477546d414759377868387057384859347a6755686e745a594434557072724c2f65356f59684a58627378764d685738377238324855545036586d6d57714e4c57394b6a746f455648316d593133534d2f4b67566a37656670546b57586e48677870425963365863736250413d3d227d7d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
        });
        bytes memory encodedBoardData = abi.encode(boardData);
        console.logBytes(encodedBoardData);
        uint256 netTokenIn = 1000000000000;
        deal(USDC, commander, netTokenIn);
        vm.prank(commander);
        IERC20(USDC).approve(address(ark), netTokenIn);
        vm.prank(governor);
        ark.setUpperEma(1.1 * 1e18);
        vm.prank(commander);
        ark.board(netTokenIn, encodedBoardData);
        uint256 susdeBalanceOfArk = IERC20(SUSDE).balanceOf(address(ark));
        console.log("susdeBalanceOfArk        : ", susdeBalanceOfArk);
        uint256 usdeBalanceOfArk = IERC20(USDE).balanceOf(address(ark));
        console.log("usdeBalanceOfArk         : ", usdeBalanceOfArk);
        uint256 usdcBalanceOfArk = IERC20(USDC).balanceOf(address(ark));
        console.log("usdcBalanceOfArk         : ", usdcBalanceOfArk);
        uint256 ptBalanceOfArk = IERC20(PT).balanceOf(address(ark));
        console.log("ptBalanceOfArk           : ", ptBalanceOfArk);
    }
    function test_Board_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, USDE, amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertApproxEqRel(
            assetsAfterDeposit,
            amount,
            0.5 ether,
            "Total assets should equal deposited amount"
        );

        // Check that the Ark has received PT tokens
        uint256 ptBalance = IERC20(PT).balanceOf(address(ark));
        assertTrue(ptBalance > 0, "Ark should have PT tokens");

        // Simulate some time passing
        vm.warp(block.timestamp + 30 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease over time"
        );
    }

    function test_Disembark_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));

        vm.warp(block.timestamp + 1 days);
        // Act
        uint256 initialBalance = usde.balanceOf(commander);
        uint256 amountToWithdraw = ark.totalAssets();
        ark.disembark(amountToWithdraw + 1, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 finalBalance = usde.balanceOf(commander);
        assertTrue(
            finalBalance > initialBalance,
            "Commander should have received USDE back"
        );

        uint256 arkBalance = ark.totalAssets();
        assertApproxEqAbs(
            arkBalance,
            0,
            1e18,
            "Ark should have close to zero assets"
        );
    }

    function test_DepositToExpireMarket_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 10 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();
        console.log(ark.marketExpiry());
        // exactly 1 block after expiry
        vm.rollFork(MARKET_EXPIRY_BLOCK);

        // Act
        vm.startPrank(commander);

        deal(USDE, commander, 10 * amount);
        usde.approve(address(ark), amount);
        vm.expectRevert(abi.encodeWithSignature("MarketExpired()"));
        ark.board(amount, bytes(""));

        vm.stopPrank();
    }

    function test_WithdrawFromExpireMarket_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 1 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();
        console.log(ark.marketExpiry());
        // exactly 1 block after expiry
        vm.rollFork(MARKET_EXPIRY_BLOCK);

        // Act
        vm.startPrank(commander);
        console.log(IERC20(PT).balanceOf(address(ark)));
        console.log(ark.totalAssets());
        ark.disembark(ark.totalAssets(), bytes(""));

        vm.stopPrank();

        // Assert
        uint256 assetsAfterDisembark = ark.totalAssets();
        console.log(IERC20(PT).balanceOf(address(ark)));
        uint256 commanderBalance = usde.balanceOf(commander);
        console.log(commanderBalance);
        assertTrue(
            assetsAfterDisembark == 0,
            "Ark should have no assets after disembark"
        );
        assertTrue(
            usde.balanceOf(commander) > 0,
            "Commander should have received USDE back"
        );
    }

    function test_RolloverIfNeeded_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 10 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.rollFork(block.number + 120000);

        // Act
        vm.startPrank(commander);

        deal(USDE, commander, 10 * amount);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));

        vm.stopPrank();

        // Assert
        uint256 assetsAfterRollover = ark.totalAssets();
        assertTrue(
            assetsAfterRollover > 0,
            "Ark should have assets after rollover"
        );
    }

    // function test_SetSlippagePercentage() public {
    //     Percentage newSlippagePercentage = PercentageUtils.fromFraction(1, 100);

    //     vm.prank(governor);
    //     ark.setSlippagePercentage(newSlippagePercentage);

    //     assertTrue(
    //         ark.slippagePercentage() == newSlippagePercentage,
    //         "Slippage Percentage not updated correctly"
    //     );
    // }

    // function test_SetSlippagePercentage_RevertOnInvalidValue() public {
    //     Percentage invalidSlippagePercentage = PercentageUtils.fromFraction(
    //         101,
    //         100
    //     );

    //     vm.prank(governor);
    //     vm.expectRevert(
    //         abi.encodeWithSignature(
    //             "SlippagePercentageTooHigh(uint256,uint256)",
    //             invalidSlippagePercentage,
    //             PERCENTAGE_100
    //         )
    //     );
    //     ark.setSlippagePercentage(invalidSlippagePercentage);
    // }

    // function test_SetOracleDuration() public {
    //     uint32 newOracleDuration = 1800; // 30 minutes

    //     vm.prank(governor);
    //     ark.setOracleDuration(newOracleDuration);

    //     assertEq(
    //         ark.oracleDuration(),
    //         newOracleDuration,
    //         "Oracle duration not updated correctly"
    //     );
    // }

    // function test_SetOracleDuration_RevertOnInvalidValue() public {
    //     uint32 invalidOracleDuration = 10 minutes; // Less than 15 minutes

    //     vm.prank(governor);
    //     vm.expectRevert(
    //         abi.encodeWithSignature(
    //             "OracleDurationTooLow(uint32,uint256)",
    //             10 minutes,
    //             15 minutes
    //         )
    //     );
    //     ark.setOracleDuration(invalidOracleDuration);
    // }

    function test_RevertWhenNoValidNextMarket() public {
        // Setup: Board some assets first
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 2 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), 2 * amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Fast forward time past market expiry
        vm.warp(ark.marketExpiry() + 1);

        // Mock _findNextMarket to return address(0)
        vm.mockCall(
            address(ark),
            abi.encodeWithSignature("nextMarket()"),
            abi.encode(address(0))
        );

        // Attempt to trigger rollover
        vm.expectRevert(abi.encodeWithSignature("InvalidNextMarket()"));
        vm.prank(commander);
        ark.board(amount, bytes(""));
    }

    function test_TotalAssets() public {
        // Setup: Board some assets first
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertApproxEqRel(
            totalAssets,
            amount,
            0.01e18,
            "Total assets should be close to deposited amount"
        );
    }

    function test_RevertOnInvalidAssetForSY() public {
        address invalidAsset = address(0x123); // Some random address

        vm.mockCall(
            SY,
            abi.encodeWithSignature("isValidTokenIn(address)", invalidAsset),
            abi.encode(false)
        );
        vm.mockCall(
            SY,
            abi.encodeWithSignature("isValidTokenOut(address)", invalidAsset),
            abi.encode(false)
        );

        ArkParams memory params = ArkParams({
            name: "Invalid Asset Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: invalidAsset,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidAssetForSY()"));
        PendlePtArkConstructorParams
            memory pendlePtArkConstructorParams = PendlePtArkConstructorParams({
                market: MARKET,
                oracle: ORACLE,
                router: ROUTER
            });
        new PendlePTArk(pendlePtArkConstructorParams, params);
    }

    function test_SetupRouterParams() public view {
        // This test assumes routerParams is made public for testing purposes
        (, uint256 guessMax, , uint256 maxIteration, uint256 eps) = ark
            .routerParams();
        assertEq(guessMax, type(uint256).max, "Incorrect guessMax");
        assertEq(maxIteration, 256, "Incorrect maxIteration");
        assertEq(eps, 1e15, "Incorrect eps");
    }

    function test_UpdateMarketData() public view {
        uint256 expectedExpiry = IPMarketV3(MARKET).expiry();
        assertEq(
            ark.marketExpiry(),
            expectedExpiry,
            "Market expiry not updated correctly"
        );
    }

    function test_Harvest_PendlePTArk_fork() public {
        // Setup: Mock reward tokens and amounts
        address[] memory mockRewardTokens = new address[](2);
        mockRewardTokens[0] = address(0x1111);
        mockRewardTokens[1] = address(0x2222);

        uint256[] memory mockRewardAmounts = new uint256[](2);
        mockRewardAmounts[0] = 100 * 1e18;
        mockRewardAmounts[1] = 200 * 1e18;

        // Mock IPMarketV3.getRewardTokens()
        vm.mockCall(
            MARKET,
            abi.encodeWithSignature("getRewardTokens()"),
            abi.encode(mockRewardTokens)
        );

        // Mock IPMarketV3.redeemRewards()
        vm.mockCall(
            MARKET,
            abi.encodeWithSignature("redeemRewards(address)", address(ark)),
            abi.encode(mockRewardAmounts)
        );

        // Mock IERC20.transfer() for both reward tokens
        for (uint256 i = 0; i < mockRewardTokens.length; i++) {
            vm.mockCall(
                mockRewardTokens[i],
                abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    raft,
                    mockRewardAmounts[i]
                ),
                abi.encode(true)
            );
        }

        // Act: Call harvest function
        vm.prank(raft);
        // Verify that transfer was called for each reward token
        for (uint256 i = 0; i < mockRewardTokens.length; i++) {
            vm.expectCall(
                mockRewardTokens[i],
                abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    raft,
                    mockRewardAmounts[i]
                )
            );
        }
        (, uint256[] memory rewardAmounts) = ark.harvest("");

        assertEq(
            rewardAmounts[0],
            mockRewardAmounts[0],
            "Expected reward amount should match mock reward amount"
        );
        assertEq(
            rewardAmounts[1],
            mockRewardAmounts[1],
            "Expected reward amount should match mock reward amount"
        );
    }
}
