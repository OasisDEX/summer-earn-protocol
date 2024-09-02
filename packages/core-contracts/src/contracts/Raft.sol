// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../errors/RaftErrors.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IRaft} from "../interfaces/IRaft.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {AuctionDefaultParameters, AuctionManagerBase, DutchAuctionLibrary} from "./AuctionManagerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Raft
 * @notice This contract manages the harvesting of rewards from Arks and conducts Dutch auctions for the reward tokens.
 * @dev Inherits from IRaft, ArkAccessManaged, and AuctionManagerBase to handle access control and auction mechanics.
 */
contract Raft is IRaft, ArkAccessManaged, AuctionManagerBase {
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;
    /// @notice Mapping of harvested rewards for each Ark and reward token

    mapping(address ark => mapping(address rewardToken => uint256 harvestedAmount))
        public harvestedRewards;
    /// @notice Mapping of ongoing auctions for each Ark and reward token
    mapping(address ark => mapping(address rewardToken => DutchAuctionLibrary.Auction))
        public auctions;
    /// @notice Mapping of unsold tokens for each Ark and reward token
    mapping(address ark => mapping(address rewardToken => uint256 remainingTokens))
        public unsoldTokens;
    /// @notice Mapping of payment tokens boarded to each Ark and reward token
    mapping(address ark => mapping(address rewardToken => uint256 paymentTokensToBoard))
        public paymentTokensToBoard;

    constructor(
        address accessManager,
        AuctionDefaultParameters memory defaultParameters
    ) ArkAccessManaged(accessManager) AuctionManagerBase(defaultParameters) {}

    /* @inheritdoc IRaft */
    function harvestAndStartAuction(
        address ark,
        address rewardToken,
        address paymentToken,
        bytes calldata extraHarvestData
    ) external onlyGovernor {
        _harvest(ark, rewardToken, extraHarvestData);
        _startAuction(ark, rewardToken, paymentToken);
    }
    /* @inheritdoc IRaft */

    function startAuction(
        address ark,
        address rewardToken,
        address paymentToken
    ) public onlyGovernor {
        _startAuction(ark, rewardToken, paymentToken);
    }
    /* @inheritdoc IRaft */

    function harvest(
        address ark,
        address rewardToken,
        bytes calldata extraHarvestData
    ) public {
        _harvest(ark, rewardToken, extraHarvestData);
    }
    /* @inheritdoc IRaft */

    function buyTokens(
        address ark,
        address rewardToken,
        uint256 amount
    ) external returns (uint256 paymentAmount) {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        paymentAmount = auction.buyTokens(amount);

        paymentTokensToBoard[ark][rewardToken] += paymentAmount;

        if (auction.state.remainingTokens == 0) {
            _settleAuction(ark, rewardToken, auction);
        }
    }
    /* @inheritdoc IRaft */

    function finalizeAuction(address ark, address rewardToken) external {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        auction.finalizeAuction();
        _settleAuction(ark, rewardToken, auction);
    }
    /* @inheritdoc IRaft */

    function getAuctionInfo(
        address ark,
        address rewardToken
    ) external view returns (DutchAuctionLibrary.Auction memory) {
        return auctions[ark][rewardToken];
    }
    /* @inheritdoc IRaft */

    function getCurrentPrice(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return _getCurrentPrice(auctions[ark][rewardToken]);
    }
    /* @inheritdoc IRaft */

    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newConfig
    ) external onlyGovernor {
        _updateAuctionDefaultParameters(newConfig);
    }
    /* @inheritdoc IRaft */

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
            revert RaftAuctionAlreadyRunning(ark, rewardToken);
        }

        uint256 totalTokens = harvestedRewards[ark][rewardToken] +
            unsoldTokens[ark][rewardToken];

        DutchAuctionLibrary.Auction memory newAuction = _createAuction(
            IERC20(rewardToken),
            IERC20(paymentToken),
            totalTokens,
            address(this)
        );
        auctions[ark][rewardToken] = newAuction;

        harvestedRewards[ark][rewardToken] = 0;
        unsoldTokens[ark][rewardToken] = 0;

        emit ArkRewardTokenAuctionStarted(
            newAuction.config.id,
            ark,
            rewardToken,
            totalTokens
        );
    }

    /**
     * @dev Settles the auction by handling unsold tokens and boarding payment tokens
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     * @param auction The auction to be settled
     */
    function _settleAuction(
        address ark,
        address rewardToken,
        DutchAuctionLibrary.Auction memory auction
    ) internal {
        unsoldTokens[ark][rewardToken] += auction.state.remainingTokens;

        IERC20 paymentToken = IERC20(auction.config.paymentToken);
        uint256 balance = paymentTokensToBoard[ark][rewardToken];
        if (balance > 0) {
            paymentToken.approve(ark, balance);
            IArk(ark).board(balance, bytes(""));

            emit RewardBoarded(
                ark,
                rewardToken,
                address(paymentToken),
                balance
            );
            paymentTokensToBoard[ark][rewardToken] = 0;
        }
    }
}
