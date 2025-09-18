// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library OracleTestHelper {
    function precision(uint8 decimals) internal pure returns (uint256) {
        return 10 ** uint256(decimals);
    }

    function applyDecimals(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        return amount * precision(decimals);
    }

    // Return expected Morpho price (1 share in asset) scaled by 1e36
    function expectedMorphoPrice(
        IERC4626 vault
    ) internal view returns (uint256) {
        uint8 shareDec = IERC20Metadata(address(vault)).decimals();
        uint8 assetDec = IERC20Metadata(vault.asset()).decimals();
        uint256 oneShare = precision(shareDec);
        uint256 assets = vault.convertToAssets(oneShare);
        return (assets * 1e36) / precision(assetDec);
    }
}
