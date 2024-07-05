// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, ERC20, SafeERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderAccessControl} from "./FleetCommanderAccessControl.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import "../libraries/PercentageUtils.sol";
import {FleetCommanderParams, ArkConfiguration} from "../types/FleetCommanderTypes.sol";
import "../errors/FleetCommanderErrors.sol";

/**
 * @custom:see IFleetCommander
 */
contract FleetCommander is IFleetCommander, FleetCommanderAccessControl, ERC4626 {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    mapping(address => ArkConfiguration) private _arks;
    uint256 public fundsBufferBalance;
    uint256 public minFundsBufferBalance;
    uint256 public lastRebalanceTime;
    uint256 public rebalanceCooldown;
    Percentage public minPositionWithdrawalPercentage;
    Percentage public maxBufferWithdrawalPercentage;

    constructor(FleetCommanderParams memory params)
        ERC4626(IERC20(params.asset))
        ERC20(params.name, params.symbol)
        FleetCommanderAccessControl(params.configurationManager)
    {
        _setupArks(params.initialArks);
        minFundsBufferBalance = params.initialFundsBufferBalance;
        rebalanceCooldown = params.initialRebalanceCooldown;
        minPositionWithdrawalPercentage = params.initialMinimumPositionWithdrawal;
        maxBufferWithdrawalPercentage = params.initialMaximumBufferWithdrawal;
    }

    /* PUBLIC - ACCESSORS */
    /// @inheritdoc IFleetCommander
    function arks(address _address) external view override returns (ArkConfiguration memory) {
        return _arks[_address];
    }

    /* PUBLIC - USER */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IFleetCommander)
        returns (uint256)
    {
        _validateWithdrawal(assets, owner);
        super.withdraw(assets, receiver, owner);

        uint256 prevQueueBalance = fundsBufferBalance;
        fundsBufferBalance = fundsBufferBalance - assets;

        emit FundsBufferBalanceUpdated(msg.sender, prevQueueBalance, fundsBufferBalance);

        return assets;
    }

    function forceWithdraw(uint256 assets, address receiver, address owner) public returns (uint256) {}

    function deposit(uint256 assets, address receiver) public override(ERC4626, IFleetCommander) returns (uint256) {
        super.deposit(assets, receiver);

        uint256 prevQueueBalance = fundsBufferBalance;
        fundsBufferBalance = fundsBufferBalance + assets;

        emit FundsBufferBalanceUpdated(msg.sender, prevQueueBalance, fundsBufferBalance);

        return assets;
    }

    /* EXTERNAL - KEEPER */
    function rebalance(bytes calldata data) external onlyKeeper {}
    function adjustBuffer(bytes calldata data) external onlyKeeper {}

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {}
    function setFeeAddress(address newAddress) external onlyGovernor {}
    function addArk(address ark, uint256 maxAllocation) external onlyGovernor {}
    function setMinBufferBalance(uint256 newBalance) external onlyGovernor {}
    function updateRebalanceCooldown(uint256 newCooldown) external onlyGovernor {}
    function forceRebalance(bytes calldata data) external onlyGovernor {}
    function emergencyShutdown() external onlyGovernor {}

    /* PUBLIC - FEES */
    function mintSharesAsFees() public {}

    /* PUBLIC - ERC20 */
    function transfer(address, uint256) public pure override(IERC20, ERC20) returns (bool) {
        revert FleetCommanderTransfersDisabled();
    }

    /* INTERNAL - REBALANCE */
    function _rebalance(bytes calldata data) internal {}

    /* INTERNAL - ARK */
    function _board(address ark, uint256 amount) internal {}
    function _disembark(address ark, uint256 amount) internal {}
    function _move(address fromArk, address toArk, uint256 amount) internal {}
    function _setupArks(ArkConfiguration[] memory _arkConfigurations) internal {}
    function _addArk(address ark, uint256 maxAllocation) internal {}

    /* INTERNAL - VALIDATIONS */
    function _validateWithdrawal(uint256 assets, address owner) internal view {
        uint256 userPosition = maxWithdraw(owner);

        // assets needs to be increased by 100 to work with fromFraction
        Percentage userWithdrawalPercentage = PercentageUtils.fromFraction(assets * 100, userPosition);
        if (userWithdrawalPercentage < minPositionWithdrawalPercentage) {
            revert WithdrawalAmountIsBelowMinThreshold();
        }

        Percentage bufferWithdrawalPercentage = PercentageUtils.fromFraction(assets * 100, fundsBufferBalance);

        if (bufferWithdrawalPercentage > maxBufferWithdrawalPercentage) {
            revert WithdrawalAmountExceedsMaxBufferLimit();
        }
    }
}
