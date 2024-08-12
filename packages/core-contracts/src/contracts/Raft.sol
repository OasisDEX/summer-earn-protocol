// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {PercentageUtils} from "@summerfi/dutch-auction/src/lib/PercentageUtils.sol";
import {Percentage} from "@summerfi/dutch-auction/src/lib/Percentage.sol";
import {IRaftEvents} from "../events/IRaftEvents.sol";
import "../errors/RaftErrors.sol";
import "../types/RaftTypes.sol";

contract Raft is IRaft, ArkAccessManaged {
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    mapping(address ark => mapping(address rewardToken => uint256 harvestedAmount))
        public harvestedRewards;
    mapping(address ark => mapping(address rewardToken => DutchAuctionLibrary.Auction))
        public auctions;
    mapping(address ark => mapping(address rewardToken => uint256 remainingTokens))
        public unsoldTokens;

    AuctionConfig public auctionConfig;
    uint256 public nextAuctionId;

    constructor(address accessManager) ArkAccessManaged(accessManager) {
        auctionConfig = AuctionConfig({
            duration: 1 days,
            startPrice: 1e18,
            endPrice: 1,
            kickerRewardPercentage: PercentageUtils.fromDecimalPercentage(5),
            decayType: DecayFunctions.DecayType.Linear
        });
    }

    function harvestAndStartAuction(
        address ark,
        address rewardToken,
        address paymentToken,
        bytes calldata extraHarvestData
    ) external onlySuperKeeper {
        _harvest(ark, rewardToken, extraHarvestData);
        _startAuction(ark, rewardToken, paymentToken);
    }

    function startAuction(
        address ark,
        address rewardToken,
        address paymentToken
    ) public onlySuperKeeper {
        _startAuction(ark, rewardToken, paymentToken);
    }

    function harvest(
        address ark,
        address rewardToken,
        bytes calldata extraHarvestData
    ) public onlySuperKeeper {
        _harvest(ark, rewardToken, extraHarvestData);
    }

    function buyTokens(
        address ark,
        address rewardToken,
        uint256 amount
    ) external {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        auction.buyTokens(amount);

        if (auction.state.remainingTokens == 0) {
            _settleAuction(ark, rewardToken, auction);
        }
    }

    function finalizeAuction(address ark, address rewardToken) external {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        auction.finalizeAuction();
        _settleAuction(ark, rewardToken, auction);
    }

    function updateAuctionConfig(
        AuctionConfig calldata newConfig
    ) external onlyGovernor {
        auctionConfig = newConfig;
        emit AuctionConfigUpdated(newConfig);
    }

    function getHarvestedRewards(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return harvestedRewards[ark][rewardToken];
    }

    function _harvest(
        address ark,
        address rewardToken,
        bytes calldata extraHarvestData
    ) internal {
        uint256 harvestedAmount = IArk(ark).harvest(
            rewardToken,
            extraHarvestData
        );
        harvestedRewards[ark][rewardToken] += harvestedAmount;
        emit ArkHarvested(ark, rewardToken);
    }

    function _startAuction(
        address ark,
        address rewardToken,
        address paymentToken
    ) internal {
        DutchAuctionLibrary.Auction storage existingAuction = auctions[ark][
            rewardToken
        ];
        if (
            existingAuction.config.auctionToken != IERC20(address(0)) &&
            !existingAuction.state.isFinalized
        ) {
            revert AuctionAlreadyRunning(ark, rewardToken);
        }

        uint256 totalTokens = harvestedRewards[ark][rewardToken] +
            unsoldTokens[ark][rewardToken];
        if (totalTokens == 0) {
            revert NoTokensToAuction();
        }

        DutchAuctionLibrary.AuctionParams memory params = DutchAuctionLibrary
            .AuctionParams({
                auctionId: nextAuctionId++,
                auctionToken: IERC20(rewardToken),
                paymentToken: IERC20(paymentToken),
                duration: auctionConfig.duration,
                startPrice: auctionConfig.startPrice,
                endPrice: auctionConfig.endPrice,
                totalTokens: totalTokens,
                kickerRewardPercentage: auctionConfig.kickerRewardPercentage,
                kicker: msg.sender,
                unsoldTokensRecipient: address(this),
                decayType: auctionConfig.decayType
            });

        DutchAuctionLibrary.Auction memory newAuction = DutchAuctionLibrary
            .createAuction(params);
        auctions[ark][rewardToken] = newAuction;

        harvestedRewards[ark][rewardToken] = 0;
        unsoldTokens[ark][rewardToken] = 0;

        emit ArkRewardTokenAuctionStarted(
            params.auctionId,
            ark,
            rewardToken,
            totalTokens
        );
    }

    function _settleAuction(
        address ark,
        address rewardToken,
        DutchAuctionLibrary.Auction memory auction
    ) internal {
        if (!auction.state.isFinalized) {
            revert AuctionNotFinalized();
        }

        unsoldTokens[ark][rewardToken] += auction.state.remainingTokens;

        IERC20 paymentToken = IERC20(auction.config.paymentToken);
        uint256 balance = auction.config.totalTokens -
            auction.state.remainingTokens;
        if (balance > 0) {
            paymentToken.approve(ark, balance);
            IArk(ark).board(balance);

            emit RewardBoarded(
                ark,
                rewardToken,
                address(paymentToken),
                balance
            );
        }
    }
}
