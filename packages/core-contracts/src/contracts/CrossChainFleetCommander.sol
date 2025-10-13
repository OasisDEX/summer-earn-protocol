// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "./FleetCommander.sol";
import {CrossChainFleetCommanderParams, FleetCommanderParams} from "../types/FleetCommanderTypes.sol";
import "../utils/CooldownEnforcer/ICooldownEnforcerEvents.sol";

import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ERC4626, IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title CrossChainFleetCommander
 * @notice Extends FleetCommander with user cooldown enforcement for MEV protection
 * @dev This contract provides the same functionality as FleetCommander but adds
 *      per-user cooldown enforcement on withdrawals and redeems to prevent MEV attacks
 *      in cross-chain scenarios
 */
contract CrossChainFleetCommander is FleetCommander {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _userLastActionTimestamps;
    uint256 private _userCooldownPeriod;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetCommander contract
     * @param params CrossChainFleetCommanderParams struct containing initialization parameters
     */
    constructor(
        CrossChainFleetCommanderParams memory params
    )
        FleetCommander(
            FleetCommanderParams({
                name: params.name,
                details: params.details,
                symbol: params.symbol,
                configurationManager: params.configurationManager,
                accessManager: params.accessManager,
                asset: params.asset,
                initialMinimumBufferBalance: params.initialMinimumBufferBalance,
                initialRebalanceCooldown: params.initialRebalanceCooldown,
                depositCap: params.depositCap,
                initialTipRate: params.initialTipRate
            })
        )
    {
        // Set user cooldown period from config
        _setUserCooldownPeriod(params.initialCooldownPeriod);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to enforce user cooldown period
     * @param user The user address to check cooldown for
     */
    modifier enforceUserCooldown(address user) {
        require(
            block.timestamp >=
                _userLastActionTimestamps[user] + _userCooldownPeriod,
            "User cooldown period not elapsed"
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommander
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
        override
        enforceUserCooldown(owner)
        returns (uint256 shares)
    {
        return super.withdrawFromBuffer(assets, receiver, owner);
    }

    /// @inheritdoc IFleetCommander
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override
        enforceUserCooldown(owner)
        returns (uint256 assets)
    {
        return super.redeem(shares, receiver, owner);
    }

    /// @inheritdoc IFleetCommander
    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override
        enforceUserCooldown(owner)
        returns (uint256 assets)
    {
        return super.redeemFromBuffer(shares, receiver, owner);
    }

    /// @inheritdoc IFleetCommander
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
        override
        enforceUserCooldown(owner)
        returns (uint256 shares)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @inheritdoc IFleetCommander
    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override
        enforceUserCooldown(owner)
        returns (uint256 totalAssetsToWithdraw)
    {
        return super.redeemFromArks(shares, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
        _updateUserLastActionTimestamp(_msgSender());
        return shares;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the cooldown period for deposits
    /// @param newCooldownPeriod The new cooldown period in seconds
    function setCooldownPeriod(
        uint256 newCooldownPeriod
    ) external override onlyCurator(address(this)) whenNotPaused {
        _setUserCooldownPeriod(newCooldownPeriod);
        emit FleetCommanderCooldownPeriodUpdated(newCooldownPeriod);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Updates the last action timestamp for a user
     * @param user The user address to update
     */
    function _updateUserLastActionTimestamp(address user) internal {
        _userLastActionTimestamps[user] = block.timestamp;
    }

    /**
     * @dev Sets the user cooldown period
     * @param newCooldown The new cooldown period in seconds
     */
    function _setUserCooldownPeriod(uint256 newCooldown) internal {
        emit CooldownUpdated(_userCooldownPeriod, newCooldown);
        _userCooldownPeriod = newCooldown;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getUserCooldownPeriod() external view override returns (uint256) {
        return _userCooldownPeriod;
    }

    function getNextUserActionTimestamp(
        address user
    ) external view returns (uint256) {
        return _userLastActionTimestamps[user] + _userCooldownPeriod;
    }

    function canUserPerformAction(address user) external view returns (bool) {
        return
            block.timestamp >=
            _userLastActionTimestamps[user] + _userCooldownPeriod;
    }
}
