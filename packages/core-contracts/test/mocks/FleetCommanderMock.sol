// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Tipper} from "../../src/contracts/Tipper.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626, ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

import {FleetConfig, RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract FleetCommanderMock is IFleetCommander, Tipper, ERC4626Mock {
    using PercentageUtils for uint256;

    FleetConfig public config;
    address[] public arks;
    mapping(address => bool) public isArkActive;

    constructor(
        address underlying,
        address configurationManager,
        Percentage initialTipRate
    ) ERC4626Mock(underlying) Tipper(configurationManager, initialTipRate) {}

    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {
        _mint(account, amount);
    }

    function testMint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function withdrawableTotalAssets() external pure returns (uint256) {
        return 0;
    }

    function totalAssets()
        public
        view
        override(IFleetCommander, ERC4626)
        returns (uint256)
    {
        return super.totalAssets();
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override(ERC4626, IERC4626) returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function deposit(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) public returns (uint256) {
        emit FleetCommanderReferral(receiver, referralCode);
        return super.deposit(assets, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(IFleetCommander, ERC4626) returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 assets,
        address receiver,
        address owner
    ) public override(IFleetCommander, ERC4626) returns (uint256) {
        return super.redeem(assets, receiver, owner);
    }

    function setTipRate(Percentage newTipRate) external {
        _setTipRate(newTipRate);
    }

    function tip() public returns (uint256) {
        return _accrueTip();
    }

    function addArk(address ark) external {
        isArkActive[ark] = true;
        arks.push(ark);
    }

    function getArks() external view returns (address[] memory) {
        return arks;
    }

    function removeArk(address ark) external {}

    function addArks(address[] memory _arks) external {}

    function adjustBuffer(RebalanceData[] calldata data) external {}

    function emergencyShutdown() external {}

    function setFleetDepositCap(uint256 newCap) external {}

    function setArkDepositCap(address ark, uint256 newDepositCap) external {}

    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external {}

    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external {}

    function setDepositCap(address ark, uint256 newDepositCap) external {}

    function setMinimumBufferBalance(uint256 newMinimumBalance) external {}

    function setStakingRewardsManager(
        address newStakingRewardsManager
    ) external {}

    function rebalance(RebalanceData[] calldata data) external {}

    function forceRebalance(RebalanceData[] calldata data) external {}

    function updateRebalanceCooldown(uint256 newCooldown) external {}

    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256) {}

    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256) {}

    function withdrawFromArks(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256) {}

    function withdrawFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256) {}

    function maxBufferWithdraw(address owner) external view returns (uint256) {}
    function maxBufferRedeem(address owner) external view returns (uint256) {}

    function getConfig() external view override returns (FleetConfig memory) {
        return config;
    }

    function bufferArk() external view returns (address) {
        return address(config.bufferArk);
    }

    function test() public {}

    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external {}

    function pause() external {}

    function unpause() external {}

    function setMinimumPauseTime(uint256 newMinimumPauseTime) external {}

    function depositAndStake(
        uint256 assets,
        address receiver
    ) external returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function depositAndStake(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) external returns (uint256) {
        return super.deposit(assets, receiver);
    }
}
