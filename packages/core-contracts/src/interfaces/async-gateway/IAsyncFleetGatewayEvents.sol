// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";

interface IAsyncFleetGatewayEvents {
    /// @notice ERC-4626 Deposit event; per ERC-7540 the first parameter is the controller.
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    /// @notice ERC-4626 Withdraw event; per ERC-7540 `owner` is the controller.
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event DepositEpochClosed(uint256 indexed epoch);
    event DepositEpochSettled(
        uint256 indexed epoch,
        uint256 assetsIn,
        uint256 sharesOut,
        Price rate
    );
    event DepositEpochRolledBack(uint256 indexed epoch);
    event DepositEpochRetried(uint256 indexed epoch);

    event RedeemEpochClosed(uint256 indexed epoch);
    event RedeemEpochSettled(
        uint256 indexed epoch,
        uint256 sharesIn,
        uint256 assetsOut,
        Price rate
    );
    event RedeemEpochRolledBack(uint256 indexed epoch);
    event RedeemEpochRetried(uint256 indexed epoch);

    event DepositRequestCanceled(
        address indexed owner,
        address indexed receiver,
        uint256 indexed epoch,
        uint256 assets
    );
    event RedeemRequestCanceled(
        address indexed owner,
        address indexed receiver,
        uint256 indexed epoch,
        uint256 shares
    );
}
