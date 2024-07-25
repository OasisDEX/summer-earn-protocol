// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";
import {IArk} from "../../interfaces/IArk.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MetaMorphoArk is Ark {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;
    IMetaMorpho public immutable metaMorpho;
    uint256 lastUpdate;
    uint256 lastTotalAssets;

    constructor(address _metaMorpho, ArkParams memory _params) Ark(_params) {
        if (_metaMorpho == address(0)) {
            revert InvalidVaultAddress();
        }
        metaMorpho = IMetaMorpho(_metaMorpho);
    }

    function rate() public view override returns (uint256 supplyRate) {
        uint256 currentTotalAssets = this.totalAssets();
        uint256 timeDelta = block.timestamp - lastUpdate;

        if (timeDelta > 0 && lastTotalAssets > 0) {
            supplyRate =
                ((currentTotalAssets - lastTotalAssets) * 365 days * RAY) /
                (lastTotalAssets * timeDelta);
        }
    }

    function totalAssets() public view override returns (uint256 assets) {
        return metaMorpho.convertToAssets(metaMorpho.balanceOf(address(this)));
    }

    function _board(uint256 amount) internal override {
        token.approve(address(metaMorpho), amount);
        metaMorpho.deposit(amount, address(this));
        poke();
    }

    function _disembark(uint256 amount) internal override {
        metaMorpho.withdraw(amount, address(this), address(this));
        poke();
    }

    function poke() public override {
        if (block.timestamp == lastUpdate) {
            emit ArkPokedTooSoon();
            return;
        }
        uint256 currentTotalAssets = this.totalAssets();
        if (currentTotalAssets == lastTotalAssets) {
            emit ArkPokedNoChange();
            return;
        }
        lastTotalAssets = currentTotalAssets;
        lastUpdate = block.timestamp;
        emit ArkPoked(lastTotalAssets, lastUpdate);
    }
}
