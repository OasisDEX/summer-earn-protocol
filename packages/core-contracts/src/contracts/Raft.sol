// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";
import {IRaft} from "../interfaces/IRaft.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {AuctionDefaultParameters, AuctionManagerBase, DutchAuctionLibrary} from "./AuctionManagerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Raft
 * @notice Manages auctions for harvested rewards from Arks and handles the buy-and-burn mechanism
 * @dev Implements IRaft interface and inherits from ArkAccessManaged and AuctionManagerBase
 * @custom:see IRaft
 */
contract Raft is IRaft, ArkAccessManaged, AuctionManagerBase {
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the Raft contract
     * @param _accessManager Address of the access manager contract
     * @param defaultParameters Default parameters for auctions
     */
    constructor(
        address _accessManager,
        AuctionDefaultParameters memory defaultParameters
    ) ArkAccessManaged(_accessManager) AuctionManagerBase(defaultParameters) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRaft
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

    /// @inheritdoc IRaft
    function sweepAndStartAuction(
        address ark,
        address[] calldata tokens,
        address paymentToken
    ) external {
        (address[] memory sweptTokens, ) = _sweep(ark, tokens);
        for (uint256 i = 0; i < sweptTokens.length; i++) {
            _startAuction(ark, sweptTokens[i], paymentToken);
        }
    }

    /// @inheritdoc IRaft
    function startAuction(
        address ark,
        address rewardToken,
        address paymentToken
    ) public onlyGovernor {
        _startAuction(ark, rewardToken, paymentToken);
    }

    /// @inheritdoc IRaft
    function harvest(address ark, bytes calldata rewardData) external {
        _harvest(ark, rewardData);
    }

    /// @inheritdoc IRaft
    function sweep(
        address ark,
        address[] calldata tokens
    )
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        (sweptTokens, sweptAmounts) = _sweep(ark, tokens);
    }

    /// @inheritdoc IRaft
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

    /// @inheritdoc IRaft
    function finalizeAuction(address ark, address rewardToken) external {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        auction.finalizeAuction();
        _settleAuction(ark, rewardToken, auction);
    }

    /// @inheritdoc IRaft
    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newConfig
    ) external onlyGovernor {
        _updateAuctionDefaultParameters(newConfig);
    }

    /// @inheritdoc IRaft
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

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRaft
    function getAuctionInfo(
        address ark,
        address rewardToken
    ) external view returns (DutchAuctionLibrary.Auction memory) {
        return auctions[ark][rewardToken];
    }

    /// @inheritdoc IRaft
    function getCurrentPrice(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return _getCurrentPrice(auctions[ark][rewardToken]);
    }

    /// @inheritdoc IRaft
    function getObtainedTokens(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return obtainedTokens[ark][rewardToken];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Harvests rewards from the specified Ark
     * @param ark The address of the Ark to harvest from
     * @param rewardData Additional data required for harvesting
     * @return harvestedTokens Array of harvested token addresses
     * @return harvestedAmounts Array of harvested token amounts
     */
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

    /**
     * @notice Sweeps tokens from the specified Ark
     * @dev Sweeps tokens from the specified Ark and updates the obtainedTokens mapping
     * @param ark The address of the Ark contract to sweep tokens from
     * @param tokens The addresses of the tokens to sweep
     * @return sweptTokens The addresses of the tokens that were swept
     * @return sweptAmounts The amounts of the tokens that were swept
     * @custom:internal-logic
     * - Calls the sweep function on the specified Ark contract
     * - Iterates through the swept tokens and updates the obtainedTokens mapping
     * @custom:effects
     * - Updates the obtainedTokens mapping for each swept token
     * - Transfers swept tokens from the Ark to this contract
     * @custom:security-considerations
     * - Ensure only the governor can call this function (enforced by onlyGovernor modifier)
     * - Validate the Ark address and token addresses
     * - Handle potential failures in the Ark's sweep function
     * - Be aware of potential gas limitations when sweeping a large number of tokens
     */
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

    /**
     * @notice Starts a new auction for a specific Ark and reward token
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token to be auctioned
     * @param paymentToken The address of the token used for payment in the auction
     * @custom:internal-logic
     * - Checks if there's an existing, unfinalized auction for the given Ark and reward token
     * - Calculates the total tokens to be auctioned (obtained + unsold)
     * - Creates a new auction using the _createAuction function
     * - Resets the obtainedTokens and unsoldTokens for the given Ark and reward token
     * @custom:effects
     * - Creates a new auction in the auctions mapping
     * - Resets obtainedTokens and unsoldTokens for the given Ark and reward token
     * - Emits an ArkRewardTokenAuctionStarted event
     * @custom:security-considerations
     * - Ensure that there's no existing unfinalized auction before starting a new one
     * - Validate that the total tokens to be auctioned is greater than zero
     */
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

    /**
     * @notice Settles an auction by handling unsold tokens and initiating boarding process
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     * @param auction The auction to be settled
     * @custom:internal-logic
     * - Adds any remaining tokens from the auction to the unsoldTokens mapping
     * - If the Ark doesn't require keeper data, initiates the boarding process
     * @custom:effects
     * - Updates the unsoldTokens mapping
     * - May initiate the boarding process for the Ark
     * @custom:security-considerations
     * - Ensure that the auction is finalized before settling
     * - Handle potential failures in the boarding process
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
     * @notice Boards the payment tokens to the Ark
     * @param rewardToken The address of the reward token
     * @param ark The address of the Ark
     * @param data The data to be passed to the Ark
     * @custom:internal-logic
     * - Retrieves the auction data for the given Ark and reward token
     * - Checks if there's a balance of payment tokens to board
     * - Approves the Ark to spend the payment tokens
     * - Calls the board function on the Ark contract
     * @custom:effects
     * - Approves the Ark to spend payment tokens
     * - Transfers payment tokens to the Ark
     * - Resets the paymentTokensToBoard balance
     * - Emits a RewardBoarded event
     * @custom:security-considerations
     * - Ensure that the Ark contract is trusted and properly implemented
     * - Handle potential failures in the token approval or boarding process
     * - Validate that the balance to board is greater than zero
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
