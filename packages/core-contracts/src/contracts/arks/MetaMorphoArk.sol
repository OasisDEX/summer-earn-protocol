// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";

contract MetaMorphoArk is Ark {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;
    IMetaMorpho public immutable metaMorpho;
    uint256 lastUpdate;
    uint256 lastPrice;

    constructor(address _metaMorpho, ArkParams memory _params) Ark(_params) {
        if (_metaMorpho == address(0)) {
            revert InvalidVaultAddress();
        }
        metaMorpho = IMetaMorpho(_metaMorpho);
    }

    function rate() public view override returns (uint256 supplyRate) {
        uint256 currentPrice = metaMorpho.convertToAssets(WAD);
        uint256 timeDelta = block.timestamp - lastUpdate;

        if (timeDelta > 0 && lastPrice > 0) {
            supplyRate =
                ((currentPrice - lastPrice) * 365 days * RAY) /
                (lastPrice * timeDelta);
        }
    }

    function totalAssets() public view override returns (uint256 assets) {
        return metaMorpho.convertToAssets(metaMorpho.balanceOf(address(this)));
    }

    function _board(uint256 amount) internal override {
        token.approve(address(metaMorpho), amount);
        metaMorpho.deposit(amount, address(this));
        this.poke();
    }

    function _disembark(uint256 amount) internal override {
        metaMorpho.withdraw(amount, address(this), address(this));
        this.poke();
    }

    function poke() public override {
        if (block.timestamp == lastUpdate) {
            emit ArkPokedTooSoon();
            return;
        }
        uint256 currentPrice = metaMorpho.convertToAssets(WAD);
        if (currentPrice == lastPrice) {
            emit ArkPokedNoChange();
            return;
        }
        lastPrice = currentPrice;
        lastUpdate = block.timestamp;
        emit ArkPoked(lastPrice, lastUpdate);
    }

    function _harvest(
        address rewardToken,
        bytes calldata
    ) internal override returns (uint256) {}
}
