// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager, ConfigurationManagerParams} from "../../src/contracts/ConfigurationManager.sol";
import "../../src/types/CommonAuctionTypes.sol";

import {FleetCommanderTestBase} from "../fleets/FleetCommanderTestBase.sol";
import {ArkMock, ArkParams} from "../mocks/ArkMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/DecayFunctions.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {console} from "forge-std/console.sol";

contract AuctionTestBase is FleetCommanderTestBase {
    using PercentageUtils for uint256;

    address public buyer = address(2);
    address public superKeeper = address(8);

    uint256 constant AUCTION_DURATION = 7 days;
    uint8 constant DECIMALS = 18;

    uint256 constant START_PRICE = 100 * 10 ** DECIMALS;
    uint256 constant END_PRICE = (0.1 * 10) ** DECIMALS;
    uint256 public KICKER_REWARD_PERCENTAGE = 0;

    BaseAuctionParameters defaultParams;

    function setUp() public virtual {
        KICKER_REWARD_PERCENTAGE = 0;
        initializeFleetCommanderWithMockArks(0);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(superKeeper);
        defaultParams = BaseAuctionParameters({
            duration: uint40(AUCTION_DURATION),
            startPrice: START_PRICE,
            endPrice: END_PRICE,
            kickerRewardPercentage: PercentageUtils.fromIntegerPercentage(0),
            decayType: DecayFunctions.DecayType.Linear
        });

        vm.label(governor, "governor");
        vm.label(buyer, "buyer");
        vm.label(treasury, "treasury");
        vm.label(superKeeper, "superKeeper");
        vm.label(address(accessManager), "accessManager");
    }

    function createMockToken(
        string memory,
        string memory,
        uint8
    ) internal returns (ERC20Mock) {
        ERC20Mock token = new ERC20Mock();
        return token;
    }

    function mintTokens(address token, address to, uint256 amount) internal {
        deal(token, to, amount);
    }

    function _getEncodedRewardData(
        address[] memory rewardTokens,
        uint256[] memory rewardAmounts
    ) internal pure returns (bytes memory) {
        ArkMock.RewardData memory rewardsData = ArkMock.RewardData({
            rewardTokens: rewardTokens,
            rewardAmounts: rewardAmounts
        });
        return abi.encode(rewardsData);
    }

    function _getEncodedRewardDataSingleToken(
        address rewardToken,
        uint256 rewardAmount
    ) internal pure returns (bytes memory) {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = rewardToken;
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = rewardAmount;

        return _getEncodedRewardData(rewardTokens, rewardAmounts);
    }
}
