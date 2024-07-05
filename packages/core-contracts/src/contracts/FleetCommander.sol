// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, ERC20, SafeERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderAccessControl} from "./FleetCommanderAccessControl.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import "../errors/FleetCommanderErrors.sol";
import {IArk} from "../interfaces/IArk.sol";

/**
 * @custom:see IFleetCommander
 */
contract FleetCommander is IFleetCommander, FleetCommanderAccessControl, ERC4626 {
    using SafeERC20 for IERC20;

    mapping(address => ArkConfiguration) internal _arks;
    uint256 public fundsQueueBalance;
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
    function arks(address arkAddress) external view returns (ArkConfiguration memory) {
        return _arks[arkAddress];
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IFleetCommander)
        returns (uint256)
    {
        super.withdraw(assets, receiver, owner);

        uint256 prevQueueBalance = fundsQueueBalance;
        uint256 newQueueBalance = fundsQueueBalance - assets;
        fundsQueueBalance = newQueueBalance;

        emit FundsQueueBalanceUpdated(msg.sender, prevQueueBalance, newQueueBalance);

        return assets;
    }

    function forceWithdraw(uint256 assets, address receiver, address owner) public returns (uint256) {}

    function deposit(uint256 assets, address receiver) public override(ERC4626, IFleetCommander) returns (uint256) {
        super.deposit(assets, receiver);

        uint256 prevQueueBalance = fundsQueueBalance;
        fundsQueueBalance = fundsQueueBalance + assets;

        emit FundsQueueBalanceUpdated(msg.sender, prevQueueBalance, fundsQueueBalance);

        return assets;
    }

    /* EXTERNAL - KEEPER */
    function rebalance(bytes calldata data) external onlyKeeper {
        RebalanceEventData[] memory rebalanceData = abi.decode(data, (RebalanceEventData[]));
        for (uint256 i = 0; i < rebalanceData.length; i++) {
            _reallocateAssets(rebalanceData[i]);
        }
        emit Rebalanced(msg.sender, rebalanceData);
    }

    function _reallocateAssets(RebalanceEventData memory data) internal {
        IArk toArk = IArk(data.toArk);
        IArk fromArk = IArk(data.fromArk);
        uint256 targetArkRate = toArk.rate();
        uint256 sourceArkRate = fromArk.rate();

        if (targetArkRate < sourceArkRate) {
            revert FleetCommanderTargetArkRateTooLow(data.toArk, targetArkRate, sourceArkRate);
        }

        if (data.toArk == address(0)) {
            revert FleetCommanderArkNotFound(data.toArk);
        }

        ArkConfiguration memory targetArkConfiguration = _arks[data.toArk];

        if (targetArkConfiguration.ark == address(0) && targetArkConfiguration.maxAllocation == 0) {
            revert FleetCommanderArkNotFound(data.toArk);
        }

        if (targetArkConfiguration.maxAllocation == 0) {
            revert FleetCommanderCantRebalanceToArk(data.toArk);
        }

        uint256 amount = data.amount;
        uint256 currentAmount = toArk.balance();
        uint256 targetAmount = currentAmount + amount;
        if (targetAmount > targetArkConfiguration.maxAllocation) {
            revert FleetCommanderCantRebalanceToArk(data.toArk);
        }

        _disembark(address(fromArk), amount);
        _board(address(toArk), amount);
    }

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

    function _setupArks(ArkConfiguration[] memory _arkConfigurations) internal {
        for (uint256 i = 0; i < _arkConfigurations.length; i++) {
            _addArk(_arkConfigurations[i].ark, _arkConfigurations[i].maxAllocation);
        }
    }

    function _addArk(address ark, uint256 maxAllocation) internal {
        _arks[ark] = ArkConfiguration(ark, maxAllocation);
        emit ArkAdded(ark, maxAllocation);
    }

    /* INTERNAL - ERC20 */
    function transfer(address, uint256) public pure override(IERC20, ERC20) returns (bool) {
        revert FleetCommanderTransfersDisabled();
    }
}
