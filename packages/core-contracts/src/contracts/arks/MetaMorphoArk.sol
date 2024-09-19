// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";

contract MetaMorphoArk is Ark {
    using SafeERC20 for IERC20;

    IMetaMorpho public immutable metaMorpho;
    uint256 lastUpdate;
    uint256 lastPrice;

    constructor(address _metaMorpho, ArkParams memory _params) Ark(_params) {
        if (_metaMorpho == address(0)) {
            revert InvalidVaultAddress();
        }
        metaMorpho = IMetaMorpho(_metaMorpho);
    }

    function totalAssets() public view override returns (uint256 assets) {
        return metaMorpho.convertToAssets(metaMorpho.balanceOf(address(this)));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        config.token.approve(address(metaMorpho), amount);
        metaMorpho.deposit(amount, address(this));
        this.poke();
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        metaMorpho.withdraw(amount, address(this), address(this));
        this.poke();
    }

    function poke() public override {
        if (block.timestamp == lastUpdate) {
            emit ArkPokedTooSoon();
            return;
        }
        uint256 currentPrice = metaMorpho.convertToAssets(Constants.WAD);
        if (currentPrice == lastPrice) {
            emit ArkPokedNoChange();
            return;
        }
        lastPrice = currentPrice;
        lastUpdate = block.timestamp;
        emit ArkPoked(lastPrice, lastUpdate);
    }

    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {}
    function _validateBoardData(bytes calldata data) internal override {}
    function _validateDisembarkData(bytes calldata data) internal override {}
}
