// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../ArkWithWithdrawalRequest.sol";
import {IProvisioner} from "../../interfaces/gauntlet/IProvisioner.sol";
import {IPriceAndFeeCalculator} from "../../interfaces/gauntlet/IPriceFeeCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Required structs for the interfaces (not defined in the provided interfaces)
struct Request {
    address user;
    uint256 amount;
    uint256 minOut;
    uint256 deadline;
    uint256 tip;
    bool isDeposit;
}

struct TokenDetails {
    uint256 minDeposit;
    uint256 maxDeposit;
    bool enabled;
}

struct VaultPriceState {
    uint128 price;
    uint32 timestamp;
    bool paused;
}

struct VaultAccruals {
    uint256 totalFees;
    uint256 lastUpdate;
}

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

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress(string name, address addr);
    error InsufficientUnits();
    error VaultPaused();

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
        // Create async deposit request
        // Parameters: token, tokensIn, minUnitsOut, solverTip, deadline, maxPriceAge, isFixedPrice
        provisioner.requestDeposit(
            config.asset,
            amount,
            0, // minUnitsOut - calculated by solver
            0, // solverTip - no tip for now
            12 hours, // deadline - 12 hour window for Aera
            1 hours, // maxPriceAge - accept prices up to 1 hour old
            false // isFixedPrice - allow dynamic pricing
        );

        emit UnitsReceived(amount, 0); // Units will be received after solving
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
        // For Aera, we'd need to track pending redemption requests
        // This is a simplified implementation - in production would track actual request states
        return 0; // TODO: Implement based on actual Aera request tracking
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Request withdrawal from Aera vault
     */
    function requestWithdrawal(uint256 amount) external onlyKeeper {
        uint256 unitsToRedeem;

        if (amount == type(uint256).max) {
            unitsToRedeem = vault.balanceOf(address(this));
        } else {
            unitsToRedeem = priceCalculator.convertTokenToUnits(
                address(vault),
                config.asset,
                amount
            );
        }

        if (unitsToRedeem == 0) return;

        // Create async redeem request
        provisioner.requestRedeem(
            config.asset,
            unitsToRedeem,
            0, // minTokensOut - calculated by solver
            0, // solverTip - no tip for now
            12 hours, // deadline - 12 hour window
            1 hours, // maxPriceAge
            false // isFixedPrice
        );

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

    /**
     * @notice Get the current vault units balance
     * @return units The amount of vault units held by this Ark
     */
    function vaultUnitsBalance() external view returns (uint256 units) {
        return vault.balanceOf(address(this));
    }

    /**
     * @notice Get the current vault state
     * @return priceState The current price state of the vault
     * @return accruals The current accruals state of the vault
     */
    function getVaultState()
        external
        view
        returns (
            VaultPriceState memory priceState,
            VaultAccruals memory accruals
        )
    {
        return priceCalculator.getVaultState(address(vault));
    }

    /**
     * @notice Check if the vault is currently paused
     * @return paused True if the vault is paused
     */
    function isVaultPaused() external view returns (bool paused) {
        return priceCalculator.isVaultPaused(address(vault));
    }
}
