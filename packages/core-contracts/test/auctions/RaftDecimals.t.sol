// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BuyAndBurn} from "../../src/contracts/BuyAndBurn.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {Raft} from "../../src/contracts/Raft.sol";

import {IArkConfigProvider} from "../../src/interfaces/IArk.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkMock, ArkParams} from "../mocks/ArkMock.sol";
import "./AuctionTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

struct TestParams {
    ERC20Mock rewardToken;
    ERC20Mock underlyingToken;
    uint8 rewardDecimals;
    uint8 underlyingDecimals;
    ArkMock mockArk;
}

contract RaftDecimalsTest is AuctionTestBase {
    using PercentageUtils for uint256;

    Raft public raftContract;
    ArkMock public mockArk18Dec;
    ArkMock public mockArk6Dec;
    ArkMock public mockArk8Dec;
    ERC20Mock public rewardToken6Dec;
    ERC20Mock public rewardToken8Dec;
    ERC20Mock public rewardToken18Dec;
    ERC20Mock public underlyingToken6Dec;
    ERC20Mock public underlyingToken8Dec;
    ERC20Mock public underlyingToken18Dec;
    address public constant MOCKED_FLEET_ADDRESS = address(666);

    function setUp() public override {
        super.setUp();
        KICKER_REWARD_PERCENTAGE = 5 * 1e18;
        defaultParams.kickerRewardPercentage = Percentage.wrap(
            KICKER_REWARD_PERCENTAGE
        );
        raftContract = new Raft(address(accessManager));

        configurationManager = new ConfigurationManager(address(accessManager));

        vm.startPrank(governor);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: address(raftContract),
                tipJar: address(1),
                treasury: treasury,
                harborCommand: address(2),
                fleetCommanderRewardsManagerFactory: address(3)
            })
        );

        rewardToken6Dec = createMockToken("Reward Token 6 Dec", "RT6", 6);
        rewardToken8Dec = createMockToken("Reward Token 8 Dec", "RT8", 8);
        rewardToken18Dec = createMockToken("Reward Token 18 Dec", "RT18", 18);
        underlyingToken6Dec = createMockToken("Payment Token 6 Dec", "PT6", 6);
        underlyingToken8Dec = createMockToken("Payment Token 8 Dec", "PT8", 8);
        underlyingToken18Dec = createMockToken(
            "Payment Token 18 Dec",
            "PT18",
            18
        );
        accessManager.grantCuratorRole(MOCKED_FLEET_ADDRESS, address(governor));
        accessManager.grantSuperKeeperRole(address(governor));

        vm.stopPrank();
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(underlyingToken18Dec),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        mockArk18Dec = new ArkMock(params);
        vm.mockCall(
            address(mockArk18Dec),
            abi.encodeWithSelector(IArkConfigProvider.commander.selector),
            abi.encode(MOCKED_FLEET_ADDRESS)
        );
        params.asset = address(underlyingToken6Dec);
        mockArk6Dec = new ArkMock(params);
        vm.mockCall(
            address(mockArk6Dec),
            abi.encodeWithSelector(IArkConfigProvider.commander.selector),
            abi.encode(MOCKED_FLEET_ADDRESS)
        );
        params.asset = address(underlyingToken8Dec);
        mockArk8Dec = new ArkMock(params);
        vm.mockCall(
            address(mockArk8Dec),
            abi.encodeWithSelector(IArkConfigProvider.commander.selector),
            abi.encode(MOCKED_FLEET_ADDRESS)
        );
        vm.stopPrank();
        mintTokens(
            address(rewardToken6Dec),
            address(mockArk6Dec),
            1000000 * 10 ** 6
        );
        mintTokens(
            address(rewardToken8Dec),
            address(mockArk6Dec),
            1000000 * 10 ** 8
        );
        mintTokens(
            address(rewardToken18Dec),
            address(mockArk6Dec),
            1000000 * 10 ** 18
        );
        mintTokens(
            address(rewardToken6Dec),
            address(mockArk8Dec),
            1000000 * 10 ** 6
        );
        mintTokens(
            address(rewardToken8Dec),
            address(mockArk8Dec),
            1000000 * 10 ** 8
        );
        mintTokens(
            address(rewardToken18Dec),
            address(mockArk8Dec),
            1000000 * 10 ** 18
        );
        mintTokens(
            address(rewardToken6Dec),
            address(mockArk18Dec),
            1000000 * 10 ** 6
        );
        mintTokens(
            address(rewardToken8Dec),
            address(mockArk18Dec),
            1000000 * 10 ** 8
        );
        mintTokens(
            address(rewardToken18Dec),
            address(mockArk18Dec),
            1000000 * 10 ** 18
        );
        mintTokens(address(underlyingToken6Dec), buyer, 10000000 * 10 ** 6);
        mintTokens(address(underlyingToken8Dec), buyer, 10000000 * 10 ** 8);
        mintTokens(address(underlyingToken18Dec), buyer, 10000000 * 10 ** 18);

        vm.startPrank(buyer);
        underlyingToken6Dec.approve(address(raftContract), type(uint256).max);
        underlyingToken8Dec.approve(address(raftContract), type(uint256).max);
        underlyingToken18Dec.approve(address(raftContract), type(uint256).max);
        vm.stopPrank();

        vm.label(address(rewardToken6Dec), "rewardToken6Dec");
        vm.label(address(rewardToken8Dec), "rewardToken8Dec");
        vm.label(address(rewardToken18Dec), "rewardToken18Dec");
        vm.label(address(underlyingToken6Dec), "underlyingToken6Dec");
        vm.label(address(underlyingToken8Dec), "underlyingToken8Dec");
        vm.label(address(underlyingToken18Dec), "underlyingToken18Dec");
        vm.label(address(raftContract), "raftContract");
        vm.label(address(mockArk18Dec), "mockArk18Dec");
        vm.label(address(mockArk6Dec), "mockArk6Dec");
        vm.label(address(mockArk8Dec), "mockArk8Dec");
    }

    function testAuction6Dec6Dec() public {
        _runAuctionTest(
            TestParams(rewardToken6Dec, underlyingToken6Dec, 6, 6, mockArk6Dec)
        );
    }

    function testAuction6Dec18Dec() public {
        _runAuctionTest(
            TestParams(
                rewardToken6Dec,
                underlyingToken18Dec,
                6,
                18,
                mockArk18Dec
            )
        );
    }

    function testAuction8Dec8Dec() public {
        _runAuctionTest(
            TestParams(rewardToken8Dec, underlyingToken8Dec, 8, 8, mockArk8Dec)
        );
    }

    function testAuction8Dec18Dec() public {
        _runAuctionTest(
            TestParams(
                rewardToken8Dec,
                underlyingToken18Dec,
                8,
                18,
                mockArk18Dec
            )
        );
    }

    function testAuction18Dec6Dec() public {
        _runAuctionTest(
            TestParams(
                rewardToken18Dec,
                underlyingToken6Dec,
                18,
                6,
                mockArk6Dec
            )
        );
    }

    function testAuction18Dec18Dec() public {
        _runAuctionTest(
            TestParams(
                rewardToken18Dec,
                underlyingToken18Dec,
                18,
                18,
                mockArk18Dec
            )
        );
    }

    function _runAuctionTest(TestParams memory params) internal {
        uint256 rewardAmount = 1000000 * 10 ** params.rewardDecimals;
        uint256 adjustedStartPrice = 100 * 10 ** params.underlyingDecimals;
        uint256 adjustedEndPrice = 50 * 10 ** params.underlyingDecimals;

        // Update auction parameters for this specific test
        vm.prank(governor);
        raftContract.setArkAuctionParameters(
            address(params.mockArk),
            address(params.rewardToken),
            BaseAuctionParameters({
                duration: uint40(AUCTION_DURATION),
                startPrice: adjustedStartPrice,
                endPrice: adjustedEndPrice,
                kickerRewardPercentage: Percentage.wrap(
                    KICKER_REWARD_PERCENTAGE
                ),
                decayType: DecayFunctions.DecayType.Linear
            })
        );

        // Harvest rewards
        vm.prank(governor);
        address[] memory _rewardTokens = new address[](1);
        _rewardTokens[0] = address(params.rewardToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = rewardAmount;

        raftContract.harvest(
            address(params.mockArk),
            _getEncodedRewardData(_rewardTokens, rewardAmounts)
        );

        // Start auction
        vm.prank(governor);
        raftContract.startAuction(
            address(params.mockArk),
            address(params.rewardToken)
        );

        // Test initial price
        uint256 currentPrice = raftContract.getCurrentPrice(
            address(params.mockArk),
            address(params.rewardToken)
        );
        assertEq(currentPrice, adjustedStartPrice, "Initial price incorrect");

        // Test price halfway through auction
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = raftContract.getCurrentPrice(
            address(params.mockArk),
            address(params.rewardToken)
        );
        assertApproxEqAbs(
            currentPrice,
            (adjustedStartPrice + adjustedEndPrice) / 2,
            1,
            "Mid-auction price incorrect"
        );

        // Test buying tokens
        uint256 buyAmount = 100000 * 10 ** params.rewardDecimals;
        vm.prank(buyer);
        uint256 tokensPaid = raftContract.buyTokens(
            address(params.mockArk),
            address(params.rewardToken),
            buyAmount
        );

        // Verify correct amount of tokens received
        assertEq(
            params.rewardToken.balanceOf(buyer),
            buyAmount,
            "Buyer did not receive correct amount of tokens"
        );

        // Test final price
        vm.warp(block.timestamp + AUCTION_DURATION / 2);
        currentPrice = raftContract.getCurrentPrice(
            address(params.mockArk),
            address(params.rewardToken)
        );
        assertEq(currentPrice, adjustedEndPrice, "Final price incorrect");

        // Finalize auction
        raftContract.finalizeAuction(
            address(params.mockArk),
            address(params.rewardToken)
        );

        // Verify unsold tokens
        uint256 kickerReward = rewardAmount.applyPercentage(
            Percentage.wrap(KICKER_REWARD_PERCENTAGE)
        );
        uint256 expectedUnsoldTokens = rewardAmount - buyAmount - kickerReward;
        {
            assertEq(
                raftContract.unsoldTokens(
                    address(params.mockArk),
                    address(params.rewardToken)
                ),
                expectedUnsoldTokens,
                "Incorrect amount of unsold tokens"
            );

            // Verify underlying tokens boarded to Ark
            uint256 expectedBoardedAmount = tokensPaid;
            assertEq(
                params.underlyingToken.balanceOf(address(params.mockArk)),
                expectedBoardedAmount,
                "Incorrect amount of underlying tokens boarded to Ark"
            );
        }
    }
}
