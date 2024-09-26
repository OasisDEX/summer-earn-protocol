// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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
        public obtainedTokens;
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
        address _accessManager,
        AuctionDefaultParameters memory defaultParameters
    ) ArkAccessManaged(_accessManager) AuctionManagerBase(defaultParameters) {}

    /* @inheritdoc IRaft */
    function harvestAndStartAuction(
        address ark,
        address paymentToken,
        bytes calldata rewardData
    ) external onlyGovernor {
        (address[] memory harvestedTokens, ) = _harvest(ark, rewardData);
        for (uint256 i = 0; i < harvestedTokens.length; i++) {
            _startAuction(ark, harvestedTokens[i], paymentToken);
        }
    }

    /* @inheritdoc IRaft */
    function sweepAndStartAuction(
        address ark,
        address[] calldata tokens,
        address paymentToken
    ) external onlyGovernor {
        (address[] memory sweptTokens, ) = _sweep(ark, tokens);
        for (uint256 i = 0; i < sweptTokens.length; i++) {
            _startAuction(ark, sweptTokens[i], paymentToken);
        }
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

    function harvest(address ark, bytes calldata rewardData) public {
        _harvest(ark, rewardData);
    }

    /* @inheritdoc IRaft */
    function sweep(
        address ark,
        address[] calldata tokens
    )
        external
        onlyGovernor
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        (sweptTokens, sweptAmounts) = _sweep(ark, tokens);
    }

    function _sweep(
        address ark,
        address[] calldata tokens
    )
        internal
        onlyGovernor
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        (sweptTokens, sweptAmounts) = IArk(ark).sweep(tokens);
        for (uint256 i = 0; i < sweptTokens.length; i++) {
            obtainedTokens[ark][sweptTokens[i]] += sweptAmounts[i];
        }
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

    function getObtainedTokens(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return obtainedTokens[ark][rewardToken];
    }

    function _harvest(
        address ark,
        bytes calldata rewardData
    )
        internal
        returns (
            address[] memory harvestedTokens,
            uint256[] memory harvestedAmounts
        )
    {
        (harvestedTokens, harvestedAmounts) = IArk(ark).harvest(rewardData);
        for (uint256 i = 0; i < harvestedTokens.length; i++) {
            obtainedTokens[ark][harvestedTokens[i]] += harvestedAmounts[i];
        }

        emit ArkHarvested(ark, harvestedTokens, harvestedAmounts);
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

        uint256 totalTokens = obtainedTokens[ark][rewardToken] +
            unsoldTokens[ark][rewardToken];

        DutchAuctionLibrary.Auction memory newAuction = _createAuction(
            IERC20(rewardToken),
            IERC20(paymentToken),
            totalTokens,
            address(this)
        );
        auctions[ark][rewardToken] = newAuction;

        obtainedTokens[ark][rewardToken] = 0;
        unsoldTokens[ark][rewardToken] = 0;

        emit ArkRewardTokenAuctionStarted(
            newAuction.config.id,
            ark,
            rewardToken,
            totalTokens
        );
    }

    function board(
        address ark,
        address rewardToken,
        bytes calldata data
    ) external onlyGovernor {
        if (!IArk(ark).requiresKeeperData()) {
            revert RaftArkDoesntRequireKeeperData(ark);
        }
        _board(rewardToken, ark, data);
    }

    /**
     * @dev Settles the auction by handling unsold tokens
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
        if (!IArk(ark).requiresKeeperData()) {
            _board(rewardToken, ark, bytes(""));
        }
    }

    /**
     * @dev Boards the payment tokens to the Ark
     * @param rewardToken The address of the reward token
     * @param ark The address of the Ark
     * @param data The data to be passed to the Ark
     */
    function _board(
        address rewardToken,
        address ark,
        bytes memory data
    ) internal {
        DutchAuctionLibrary.Auction memory auction = auctions[ark][rewardToken];
        IERC20 paymentToken = IERC20(auction.config.paymentToken);

        uint256 balance = paymentTokensToBoard[ark][rewardToken];
        if (balance > 0) {
            IArk(ark).requiresKeeperData();
            paymentToken.approve(ark, balance);
            IArk(ark).board(balance, data);

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
