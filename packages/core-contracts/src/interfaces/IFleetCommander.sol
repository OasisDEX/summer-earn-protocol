// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IFleetCommanderAccessControl} from "./IFleetCommanderAccessControl.sol";
import "../types/Percentage.sol";
import {FleetCommanderParams, ArkConfiguration} from "../types/FleetCommanderTypes.sol";

interface IFleetCommander is IFleetCommanderAccessControl, IERC4626 {
    /* STRUCTS */
    /**
     * @notice Data structure for the rebalance event
     */
    struct RebalanceEventData {
        address fromArk;
        address toArk;
        uint256 amount;
    }

    /* EVENTS */
    event Rebalanced(address indexed keeper, RebalanceEventData[] rebalances);
    event QueuedFundsCommitted(
        address indexed keeper,
        uint256 prevBalance,
        uint256 newBalance
    );
    event FundsQueueRefilled(
        address indexed keeper,
        uint256 prevBalance,
        uint256 newBalance
    );
    event MinFundsQueueBalanceUpdated(
        address indexed keeper,
        uint256 newBalance
    );
    event DepositCapUpdated(uint256 newCap);
    event FeeAddressUpdated(address newAddress);
    event ArkAdded(address indexed ark, uint256 maxAllocation);

    event FundsBufferBalanceUpdated(
        address indexed user,
        uint256 prevBalance,
        uint256 newBalance
    );

    /**
     * @notice The ark configuration for a given ark (by address).
     */
    function arks(
        address arkAddress
    ) external view returns (ArkConfiguration memory);

    /* FUNCTIONS - PUBLIC - USER */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external override returns (uint256);

    function forceWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256);

    /* FUNCTIONS - EXTERNAL - KEEPER */
    function rebalance(bytes calldata data) external;

    function adjustBuffer(bytes calldata data) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external;

    function setFeeAddress(address newAddress) external;

    function addArk(address ark, uint256 maxAllocation) external;

    function setMinFundsQueueBalance(uint256 newBalance) external;

    function updateRebalanceCooldown(uint256 newCooldown) external;

    function forceRebalance(bytes calldata data) external;

    function emergencyShutdown() external;

    /* FUNCTIONS - PUBLIC - FEES */
    function mintSharesAsFees() external;
}
