// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {SummerToken} from "../../src/contracts/SummerToken.sol";
import "../../src/types/CommonAuctionTypes.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test, console} from "forge-std/Test.sol";

contract AuctionTestBase is Test {
    using PercentageUtils for uint256;

    ProtocolAccessManager public accessManager;

    address public governor = address(1);
    address public buyer = address(2);
    address public treasury = address(3);
    address public superKeeper = address(8);

    uint256 constant AUCTION_DURATION = 7 days;
    uint8 constant DECIMALS = 18;

    uint256 constant START_PRICE = 100 * 10 ** DECIMALS;
    uint256 constant END_PRICE = (0.1 * 10) ** DECIMALS;
    uint256 public KICKER_REWARD_PERCENTAGE = 0;

    AuctionDefaultParameters defaultParams;

    function setUp() public virtual {
        KICKER_REWARD_PERCENTAGE = 0;
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(superKeeper);

        defaultParams = AuctionDefaultParameters({
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
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal returns (MockERC20) {
        MockERC20 token = new MockERC20();
        token.initialize(name, symbol, decimals);
        return token;
    }

    function mintTokens(address token, address to, uint256 amount) internal {
        deal(token, to, amount);
    }
}
