// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CarryTradeArk.sol";

/**
 * @title AaveV3BorrowArk
 * @notice Ark for depositing collateral to Aave V3, borrowing assets, and depositing to yield fleet
 */
abstract contract AaveV3BorrowArk is CarryTradeArk {
    using SafeERC20 for IERC20;

    IPoolV3 public immutable aaveV3Pool;
    IRewardsController public immutable rewardsController;

    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        address _borrowedAsset,
        address _fleet,
        ArkParams memory _params
    )
        CarryTradeArk(
            CarryTradeParams({
                _lendingPool: _aaveV3Pool,
                _collateralAsset: _params.asset,
                _borrowedAsset: _borrowedAsset,
                _yieldVault: _fleet,
                _collateralToken: IPoolV3(_aaveV3Pool)
                    .getReserveData(_params.asset)
                    .aTokenAddress,
                _debtToken: IPoolV3(_aaveV3Pool)
                    .getReserveData(_borrowedAsset)
                    .variableDebtTokenAddress,
                baseParams: _params
            })
        )
    {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        rewardsController = IRewardsController(_rewardsController);
    }

    function _supplyCollateral(uint256 amount) internal override {
        collateralAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(collateralAsset), amount, address(this), 0);
    }

    function _borrowAsset(uint256 amount) internal override {
        aaveV3Pool.borrow(
            address(borrowedAsset),
            amount,
            2, // variable rate
            0,
            address(this)
        );
    }

    function _depositToYieldVault(uint256 amount) internal override {
        borrowedAsset.forceApprove(yieldVault, amount);
        IERC4626(yieldVault).deposit(amount, address(this));
    }

    function _withdrawFromYieldVault(uint256 amount) internal override {
        IERC4626(yieldVault).withdraw(amount, address(this), address(this));
    }

    function _repayBorrow(uint256 amount) internal override {
        borrowedAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.repay(address(borrowedAsset), amount, 2, address(this));
    }

    function _withdrawCollateral(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(collateralAsset), amount, address(this));
    }

    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        address[] memory assets = new address[](2);
        assets[0] = collateralToken;
        assets[1] = debtToken;

        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);

        try rewardsController.claimAllRewards(assets, address(this)) returns (
            address[] memory tokens,
            uint256[] memory amounts
        ) {
            rewardTokens = tokens;
            rewardAmounts = amounts;
        } catch {
            // If claiming rewards fails, return empty arrays
        }
    }
}
