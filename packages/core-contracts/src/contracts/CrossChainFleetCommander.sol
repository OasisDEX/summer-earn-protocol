// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "./FleetCommander.sol";
import {ICrossChainFleetCommander} from "../interfaces/ICrossChainFleetCommander.sol";
import {CrossChainFleetCommanderParams} from "../types/CrossChainFleetCommanderTypes.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../errors/ICrossChainFleetCommanderErrors.sol";

/**
 * @title CrossChainFleetCommander
 * @notice A FleetCommander implementation with cross-chain cooldown protection mechanisms
 * @dev Extends the base FleetCommander to add cooldown periods between deposits and withdrawals/redemptions.
 *      This prevents rapid deposit-withdraw cycles that could be exploited in cross-chain scenarios.
 *
 * Key Features:
 * - Enforces cooldown periods after deposits before allowing withdrawals/redemptions
 * - Propagates cooldown timestamps when shares are transferred between users
 * - Maintains individual cooldown tracking per user address
 * - Emits events for cooldown propagation to enable off-chain monitoring
 *
 * Security Considerations:
 * - Cooldown periods help prevent MEV attacks and rapid arbitrage in cross-chain contexts
 * - Transfer cooldown propagation ensures cooldown protection isn't bypassed via transfers
 * - Only applies cooldown to withdrawal/redemption operations, not deposits
 */
contract CrossChainFleetCommander is FleetCommander, ICrossChainFleetCommander {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Maps user addresses to their last deposit timestamp
     * @dev Used to enforce cooldown periods between deposits and withdrawals/redemptions
     *      Timestamp is set to 0 for users who have never deposited
     */
    mapping(address user => uint256 timestamp) public lastDepositTimestamp;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetCommander contract
     * @param params CrossChainFleetCommanderParams struct containing initialization parameters
     * @dev Calls the parent FleetCommander constructor and sets the user-specific cooldown period
     *      without affecting the rebalancing cooldown period
     */
    constructor(
        CrossChainFleetCommanderParams memory params
    ) FleetCommander(params.fleetCommanderParams) {
        config.userCooldownPeriod = params.cooldownPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier that enforces cooldown period before allowing withdrawal/redemption operations
     * @param user The address of the user attempting the operation
     * @dev Reverts if the user's last deposit was within the cooldown period
     *      Only applies when user cooldown period is greater than 0
     */
    modifier cooldownEnforced(address user) {
        uint256 lastDeposit = lastDepositTimestamp[user];
        if (
            lastDeposit > 0 &&
            config.userCooldownPeriod > 0 &&
            block.timestamp <= lastDeposit + config.userCooldownPeriod
        ) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderCooldownNotMet(
                    user,
                    block.timestamp,
                    lastDeposit + config.userCooldownPeriod
                );
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override of ERC20 _update to handle cooldown timestamp propagation
     * @param from The address tokens are transferred from (0 for minting)
     * @param to The address tokens are transferred to (0 for burning)
     * @param value The amount of tokens being transferred
     * @dev When shares are transferred between non-zero addresses, propagates the cooldown timestamp
     *      from sender to recipient if the sender has a more recent (or only) cooldown timestamp.
     *      This prevents users from bypassing cooldown restrictions by transferring shares.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        // Call parent _update to handle the actual transfer
        super._update(from, to, value);

        // Only propagate cooldown for transfers between non-zero addresses (not mint/burn)
        if (from != address(0) && to != address(0)) {
            uint256 fromTimestamp = lastDepositTimestamp[from];
            uint256 toTimestamp = lastDepositTimestamp[to];

            // Propagate cooldown if sender has a timestamp and it's more recent than recipient's
            if (
                fromTimestamp > 0 &&
                (fromTimestamp < toTimestamp || toTimestamp == 0)
            ) {
                lastDepositTimestamp[to] = fromTimestamp;
                emit FleetCommanderCooldownPropagated(from, to, fromTimestamp);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets and mints shares to the receiver
     * @param assets The amount of assets to deposit
     * @param receiver The address to receive the minted shares
     * @return shares The amount of shares minted to the receiver
     * @dev Updates the receiver's last deposit timestamp to the current block timestamp
     *      This timestamp will be used to enforce cooldown periods for future withdrawals/redemptions
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
        lastDepositTimestamp[receiver] = block.timestamp;
    }

    /**
     * @notice Withdraws assets by burning shares from the owner
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the withdrawn assets
     * @param owner The address that owns the shares being burned
     * @return shares The amount of shares burned from the owner
     * @dev Enforces cooldown period - owner must not have deposited within the cooldown period
     *      Reverts with CrossChainFleetCommanderCooldownNotMet if cooldown is not satisfied
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override cooldownEnforced(owner) returns (uint256 shares) {
        shares = super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Redeems shares for assets
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the redeemed assets
     * @param owner The address that owns the shares being redeemed
     * @return assets The amount of assets redeemed
     * @dev Enforces cooldown period - owner must not have deposited within the cooldown period
     *      Reverts with CrossChainFleetCommanderCooldownNotMet if cooldown is not satisfied
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override cooldownEnforced(owner) returns (uint256 assets) {
        assets = super.redeem(shares, receiver, owner);
    }

    /**
     * @notice Withdraws assets from the buffer by burning shares from the owner
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the withdrawn assets
     * @param owner The address that owns the shares being burned
     * @return shares The amount of shares burned from the owner
     * @dev Enforces cooldown period - owner must not have deposited within the cooldown period
     *      Reverts with CrossChainFleetCommanderCooldownNotMet if cooldown is not satisfied
     */
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    ) public override cooldownEnforced(owner) returns (uint256 shares) {
        shares = super.withdrawFromBuffer(assets, receiver, owner);
    }

    /**
     * @notice Redeems shares from the buffer for assets
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the redeemed assets
     * @param owner The address that owns the shares being redeemed
     * @return assets The amount of assets redeemed
     * @dev Enforces cooldown period - owner must not have deposited within the cooldown period
     *      Reverts with CrossChainFleetCommanderCooldownNotMet if cooldown is not satisfied
     */
    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) public override cooldownEnforced(owner) returns (uint256 assets) {
        assets = super.redeemFromBuffer(shares, receiver, owner);
    }

    /**
     * @notice Withdraws assets from arks by burning shares from the owner
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the withdrawn assets
     * @param owner The address that owns the shares being burned
     * @return shares The amount of shares burned from the owner
     * @dev Enforces cooldown period - owner must not have deposited within the cooldown period
     *      Reverts with CrossChainFleetCommanderCooldownNotMet if cooldown is not satisfied
     */
    function withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    ) public override cooldownEnforced(owner) returns (uint256 shares) {
        shares = super.withdrawFromArks(assets, receiver, owner);
    }

    /**
     * @notice Redeems shares from arks for assets
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the redeemed assets
     * @param owner The address that owns the shares being redeemed
     * @return assets The amount of assets redeemed
     * @dev Enforces cooldown period - owner must not have deposited within the cooldown period
     *      Reverts with CrossChainFleetCommanderCooldownNotMet if cooldown is not satisfied
     */
    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    ) public override cooldownEnforced(owner) returns (uint256 assets) {
        assets = super.redeemFromArks(shares, receiver, owner);
    }
}
