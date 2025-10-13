// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "./FleetCommander.sol";
import {ICrossChainFleetCommander} from "../interfaces/ICrossChainFleetCommander.sol";
import {CrossChainFleetCommanderParams} from "../types/CrossChainFleetCommanderTypes.sol";
import {FleetCommanderParams, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../errors/ICrossChainFleetCommanderErrors.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title CrossChainFleetCommander
 * @notice FleetCommander variant with cooldown-based MEV protection
 * @dev Implements a cooldown period between deposits and withdrawals to prevent
 *      MEV attacks and sandwich attacks on cross-chain operations
 */
contract CrossChainFleetCommander is FleetCommander, ICrossChainFleetCommander {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of user address to their last deposit timestamp
    mapping(address => uint256) public lastDepositTimestamp;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChain FleetCommander
     * @param params CrossChainFleetCommanderParams struct containing initialization parameters
     */
    constructor(
        CrossChainFleetCommanderParams memory params
    ) FleetCommander(params.fleetCommanderParams) {
        // Initialize cooldown period in FleetConfig
        config.cooldownPeriod = params.cooldownPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to ensure cooldown period has passed since last deposit
     * @dev This prevents immediate withdraw/redeem after deposit for MEV protection
     */
    modifier cooldownEnforced(address user) {
        uint256 lastDeposit = lastDepositTimestamp[user];
        if (
            lastDeposit > 0 &&
            config.cooldownPeriod > 0 &&
            block.timestamp <= lastDeposit + config.cooldownPeriod
        ) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderCooldownNotMet(
                    user,
                    block.timestamp,
                    lastDeposit + config.cooldownPeriod
                );
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            COOLDOWN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the cooldown period
    function getCooldownPeriod() external view returns (uint256 period) {
        return config.cooldownPeriod;
    }

    /// @notice Get the timestamp when a user can next withdraw/redeem
    function getNextWithdrawTimestamp(
        address user
    ) external view returns (uint256 timestamp) {
        uint256 lastDeposit = lastDepositTimestamp[user];
        if (lastDeposit == 0) {
            return 0; // No previous deposit
        }
        return lastDeposit + config.cooldownPeriod;
    }

    /// @notice Check if a user can withdraw/redeem (cooldown has passed)
    function canWithdraw(
        address user
    ) external view returns (bool canWithdrawNow) {
        uint256 lastDeposit = lastDepositTimestamp[user];
        if (lastDeposit == 0) {
            return true; // No previous deposit
        }
        if (config.cooldownPeriod == 0) {
            return true; // No cooldown period
        }
        return block.timestamp > lastDeposit + config.cooldownPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update the last deposit timestamp for a user
     * @param user The address of the user who deposited
     */
    function _updateLastDepositTimestamp(address user) internal {
        lastDepositTimestamp[user] = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetCommander
    function totalAssets()
        public
        view
        override(FleetCommander, IFleetCommander)
        returns (uint256)
    {
        return _totalAssets(config.bufferArk);
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDDEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override deposit to track timestamp for cooldown
     * @dev Updates the last deposit timestamp to enforce cooldown on withdrawals.
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public override(FleetCommander, IERC4626) returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
        _updateLastDepositTimestamp(_msgSender());
        return shares;
    }

    /**
     * @notice Override withdraw to enforce cooldown
     * @dev Ensures cooldown period has passed since last deposit
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(FleetCommander, IFleetCommander)
        cooldownEnforced(owner)
        returns (uint256 shares)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Override redeem to enforce cooldown
     * @dev Ensures cooldown period has passed since last deposit
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(FleetCommander, IFleetCommander)
        cooldownEnforced(owner)
        returns (uint256 assets)
    {
        return super.redeem(shares, receiver, owner);
    }
}
