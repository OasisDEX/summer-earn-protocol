// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, ERC20, SafeERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderAccessControl} from "./FleetCommanderAccessControl.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

/**
 * @custom:see IFleetCommander
 */
contract FleetCommander is IFleetCommander, FleetCommanderAccessControl, ERC4626 {
    using SafeERC20 for IERC20;

    /// @inheritdoc IFleetCommander
    mapping(address => ArkConfiguration) public arks;
    uint256 public totalQueuedFunds;
    uint256 public minFundsQueueBalance;
    uint256 public lastRebalanceTime;
    uint256 public rebalanceCooldown;

    constructor(FleetCommanderParams memory params)
        ERC4626(IERC20(params.asset))
        ERC20(params.name, params.symbol)
        FleetCommanderAccessControl(params.governor)
    {
        _setupArks(params.initialArks);
        minFundsQueueBalance = params.initialFundsQueueBalance;
        rebalanceCooldown = params.initialRebalanceCooldown;
    }

    /* PUBLIC - USER */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IFleetCommander)
        returns (uint256)
    {}
    function forceWithdraw(uint256 assets, address receiver, address owner) public returns (uint256) {}
    function deposit(uint256 assets, address receiver) public override(ERC4626, IFleetCommander) returns (uint256) {}

    /* EXTERNAL - KEEPER */
    function rebalance(bytes calldata data) external onlyKeeper {}
    function commitFundsQueue(bytes calldata data) external onlyKeeper {}
    function refillFundsQueue(bytes calldata data) external onlyKeeper {}

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {}
    function setFeeAddress(address newAddress) external onlyGovernor {}
    function addArk(address ark, uint256 maxAllocation) external onlyGovernor {}
    function setMinFundsQueueBalance(uint256 newBalance) external onlyGovernor {}
    function updateRebalanceCooldown(uint256 newCooldown) external onlyGovernor {}
    function forceRebalance(bytes calldata data) external onlyGovernor {}
    function emergencyShutdown() external onlyGovernor {}

    /* PUBLIC - FEES */
    function mintSharesAsFees() public {}

    /* INTERNAL - REBALANCE */
    function _rebalance(bytes calldata data) internal {}

    /* INTERNAL - ARK */
    function _board(address ark, uint256 amount) internal {}
    function _disembark(address ark, uint256 amount) internal {}
    function _move(address fromArk, address toArk, uint256 amount) internal {}
    function _setupArks(ArkConfiguration[] memory _arks) internal {}
    function _addArk(address ark, uint256 maxAllocation) internal {}
}
