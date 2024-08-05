// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {ERC4626Mock, ERC4626, ERC20} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {Tipper} from "../../src/contracts/Tipper.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Percentage} from "../../src/types/Percentage.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";

contract FleetCommanderMock is IFleetCommander, Tipper, ERC4626Mock {
    using PercentageUtils for uint256;

    address[] public arks;

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

    function deposit(
        uint256 assets,
        address receiver
    ) public override(IFleetCommander, ERC4626) returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(IFleetCommander, ERC4626) returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    function forceWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256) {}

    function setTipRate(Percentage newTipRate) external {
        _setTipRate(newTipRate);
    }

    function setTipJar() external {
        _setTipJar();
    }

    function tip() public returns (uint256) {
        return _accrueTip();
    }

    function getArks() external view returns (address[] memory) {
        return arks;
    }

    function addArk(address ark) external {}

    function removeArk(address ark) external {}

    function isArkActive(address) external pure returns (bool) {
        return false;
    }

    function addArks(address[] memory _arks) external {}

    function adjustBuffer(RebalanceData[] calldata data) external {}

    function emergencyShutdown() external {}

    function setDepositCap(uint256 newCap) external {}

    function setMaxAllocation(address ark, uint256 newMaxAllocation) external {}

    function rebalance(RebalanceData[] calldata data) external {}

    function forceRebalance(RebalanceData[] calldata data) external {}

    function updateRebalanceCooldown(uint256 newCooldown) external {}

    function maxForceWithdraw(address owner) external view returns (uint256) {}

    function test() public {}
}
