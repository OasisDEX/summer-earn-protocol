// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IProvisioner} from "../../interfaces/gauntlet/IProvisioner.sol";
import {IPriceAndFeeCalculator} from "../../interfaces/gauntlet/IPriceFeeCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {RequestType} from "../../interfaces/gauntlet/Types.sol";

/**
 * @title AeraArk
 * @notice Ark contract for managing token supply and yield generation through Aera/Gauntlet Alpha vaults
 * @dev Implements strategy for async depositing tokens via Provisioner and managing vault units with 12h delays
 */
contract AeraArk is ArkWithWithdrawalRequest {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Aera provisioner contract
    IProvisioner public immutable provisioner;

    /// @notice The price and fee calculator contract
    IPriceAndFeeCalculator public immutable priceCalculator;

    /// @notice The vault contract (multi-depositor vault)
    IERC20 public immutable vault;

    /// @notice Tracks pending deposit requests
    mapping(bytes32 => uint256) public pendingDepositRequests;

    /// @notice Tracks pending redeem requests
    mapping(bytes32 => uint256) public pendingRedeemRequests;

    struct ArkRequest {
        bytes32 hash;
        uint256 amount;
    }

    ArkRequest public asyncDepositRequest;

    ArkRequest public asyncRedeemRequest;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress(string name, address addr);
    error AsyncDepositAlreadyExists();
    error AsyncRedeemAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event UnitsReceived(uint256 tokensIn, uint256 unitsOut);
    event TokensRedeemed(uint256 unitsIn, uint256 tokensOut);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the AeraArk
     * @param _provisioner Address of the Aera provisioner contract
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _provisioner,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, 15) {
        if (_provisioner == address(0)) {
            revert InvalidAddress("provisioner", _provisioner);
        }

        provisioner = IProvisioner(_provisioner);
        vault = IERC20(provisioner.MULTI_DEPOSITOR_VAULT());
        priceCalculator = IPriceAndFeeCalculator(
            provisioner.PRICE_FEE_CALCULATOR()
        );

        // Approve the provisioner to spend the Ark's tokens
        config.asset.forceApprove(_provisioner, Constants.MAX_UINT256);
    }

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark in the Aera vault
     * @return assets The total balance of underlying assets represented by vault units
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        // Include withdrawable assets (processed tokens)
        assets += _withdrawableTotalAssets();

        // Include assets in withdrawal queue
        assets += assetsInWithdrawalQueue();

        // Include value of vault units held by Ark
        uint256 vaultUnits = vault.balanceOf(address(this));
        if (vaultUnits > 0) {
            assets += priceCalculator.convertUnitsToToken(
                address(vault),
                config.asset,
                vaultUnits
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev For Aera, this is tokens that have been processed and are sitting in the contract
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        // Return the balance of underlying asset tokens that have been processed
        return config.asset.balanceOf(address(this));
    }

    /**
     * @notice Requests async deposit into the Aera vault via the provisioner
     * @param amount The amount of assets to deposit
     * @param /// data Additional data (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        if (provisioner.asyncDepositHashes(asyncDepositRequest.hash)) {
            revert AsyncDepositAlreadyExists();
        }
        // Create async deposit request
        uint256 shareAtTheTimeOfDeposit = priceCalculator.convertTokenToUnits(
            address(vault),
            config.asset,
            amount
        );
        config.asset.forceApprove(address(provisioner), amount);
        provisioner.requestDeposit(
            config.asset,
            amount,
            shareAtTheTimeOfDeposit, // minUnitsOut - calculated by solver
            0, // either solverTip == 0 or isFixedPrice == true
            block.timestamp + 24 hours,
            1 hours,
            false // isFixedPrice - allow dynamic pricing
        );
        bytes32 requestHash = _getRequestHashParams(
            config.asset,
            address(this),
            RequestType.DEPOSIT_AUTO_PRICE,
            amount,
            shareAtTheTimeOfDeposit,
            0,
            block.timestamp + 24 hours,
            1 hours
        );
        asyncDepositRequest = ArkRequest({hash: requestHash, amount: amount});
    }

    /**
     * @notice No-op for _disembark since withdrawals are handled via request system
     * @param /// amount The amount of assets to withdraw (unused)
     * @param /// data Additional data (unused)
     */
    function _disembark(uint256, bytes calldata) internal override {
        // No-op: disembark is handled by ArkWithWithdrawalRequest contract implementation
        // Withdrawals must be requested through requestWithdrawal()
    }

    /**
     * @notice Internal function for harvesting rewards
     * @dev Aera vaults auto-compound, so harvest just returns empty arrays
     * @param /// data Additional data (unused in this implementation)
     * @return rewardTokens Empty array (auto-compounding vault)
     * @return rewardAmounts Empty array (auto-compounding vault)
     */
    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // Aera vaults are auto-compounding, no separate reward tokens to harvest
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /**
     * @notice Validates the board data
     * @dev This Ark does not require any validation for board data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata) internal pure override {}

    /**
     * @notice Validates the disembark data
     * @dev This Ark does not require any validation for disembark data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(bytes calldata) internal pure override {}

    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL REQUEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Returns assets currently in the withdrawal queue
     */
    function assetsInWithdrawalQueue() public view returns (uint256) {
        if (provisioner.asyncRedeemHashes(asyncRedeemRequest.hash)) {
            return asyncRedeemRequest.amount;
        }
        return 0;
    }

    function assetsInDepositQueue() public view returns (uint256) {
        if (provisioner.asyncDepositHashes(asyncDepositRequest.hash)) {
            return asyncDepositRequest.amount;
        }
        return 0;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Request withdrawal from Aera vault
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        if (provisioner.asyncRedeemHashes(asyncRedeemRequest.hash)) {
            revert AsyncRedeemAlreadyExists();
        }
        uint256 sharesToRedeem;

        if (amount == type(uint256).max) {
            sharesToRedeem = vault.balanceOf(address(this));
        } else {
            sharesToRedeem = priceCalculator.convertTokenToUnits(
                address(vault),
                config.asset,
                amount
            );
        }

        if (sharesToRedeem == 0) return;
        uint256 minTokensOut = priceCalculator.convertUnitsToToken(
            address(vault),
            config.asset,
            sharesToRedeem
        );
        vault.forceApprove(address(provisioner), sharesToRedeem);
        // Create async redeem request
        provisioner.requestRedeem(
            config.asset,
            sharesToRedeem,
            minTokensOut,
            0, // solverTip - no tip for now
            block.timestamp + 24 hours,
            1 hours,
            false // isFixedPrice
        );

        bytes32 requestHash = _getRequestHashParams(
            config.asset,
            address(this),
            RequestType.REDEEM_AUTO_PRICE,
            sharesToRedeem,
            0,
            0,
            block.timestamp + 24 hours,
            1 hours
        );
        asyncRedeemRequest = ArkRequest({hash: requestHash, amount: amount});

        emit WithdrawalRequested(amount, 0); // Request ID would come from provisioner
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Claim completed withdrawal (Aera handles automatically)
     */
    function claimWithdrawal() external onlyKeeper {
        // Aera processes withdrawals automatically once solved
        // No action needed - tokens will appear in contract balance
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Check if withdrawal claim is required
     */
    function isWithdrawalClaimRequired() public pure returns (bool) {
        return false; // Aera handles automatically
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Get current withdrawal request ID
     */
    function withdrawalRequestId() external pure returns (uint256) {
        return 0; // TODO: Implement proper request ID tracking
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Emergency withdrawal using swap
     */
    function withdrawUsingSwap(
        uint256 amount,
        bytes calldata data
    ) external onlyKeeper nonReentrant {
        uint256 unitsToSwap = priceCalculator.convertTokenToUnits(
            address(vault),
            config.asset,
            amount
        );

        SwapData memory swapData = abi.decode(data, (SwapData));
        uint256 assetReceived = _swap(
            address(vault),
            address(config.asset),
            swapData.router,
            unitsToSwap,
            _applySlippage(amount),
            swapData.swapCalldata
        );

        emit Disembarked(msg.sender, address(config.asset), amount);
        _boardToBufferArk(assetReceived);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the hash of a request from parameters
    /// @param token The token that was deposited or redeemed
    /// @param user The user who made the request
    /// @param requestType The type of request
    /// @param tokens The amount of tokens in the request
    /// @param units The amount of units in the request
    /// @param solverTip The tip paid to the solver
    /// @param deadline The deadline of the request
    /// @param maxPriceAge The maximum age of the price data
    /// @return The hash of the request
    function _getRequestHashParams(
        IERC20 token,
        address user,
        RequestType requestType,
        uint256 tokens,
        uint256 units,
        uint256 solverTip,
        uint256 deadline,
        uint256 maxPriceAge
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    token,
                    user,
                    requestType,
                    tokens,
                    units,
                    solverTip,
                    deadline,
                    maxPriceAge
                )
            );
    }
}
