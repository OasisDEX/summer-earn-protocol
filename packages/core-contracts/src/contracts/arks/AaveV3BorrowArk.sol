// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Ark.sol";

/**
 * @title AaveV3BorrowArk
 * @notice Ark for depositing collateral to Aave V3, borrowing assets, and depositing to yield fleet
 */
abstract contract AaveV3BorrowArk is Ark {
    using SafeERC20 for IERC20;
    
    address public immutable collateralAToken;
    address public immutable borrowedAToken;
    IPoolV3 public immutable aaveV3Pool;
    IRewardsController public immutable rewardsController;
    address public immutable fleet;
    IERC20 public immutable borrowedAsset;
    IERC20 public immutable collateralAsset;

    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        address _borrowedAsset,
        address _fleet,
        ArkParams memory _params
    ) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        rewardsController = IRewardsController(_rewardsController);
        fleet = _fleet;
        borrowedAsset = IERC20(_borrowedAsset);
        collateralAsset = config.asset;

        DataTypes.ReserveData memory collateralData = aaveV3Pool.getReserveData(
            address(config.asset)
        );
        collateralAToken = collateralData.aTokenAddress;

        DataTypes.ReserveData memory borrowedData = aaveV3Pool.getReserveData(
            _borrowedAsset
        );
        borrowedAToken = borrowedData.aTokenAddress;
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(collateralAToken).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata data) internal override {
        uint256 borrowAmount = abi.decode(data, (uint256));
        
        // Supply collateral
        collateralAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(collateralAsset), amount, address(this), 0);
        
        // Borrow assets
        aaveV3Pool.borrow(address(borrowedAsset), borrowAmount, 2, 0, address(this));
        
        // Deposit to fleet
        borrowedAsset.forceApprove(fleet, borrowAmount);
        IERC4626(fleet).deposit(borrowAmount, msg.sender);
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        // Withdraw from fleet
        uint256 fleetBalance = IERC4626(fleet).balanceOf(address(this));
        IERC4626(fleet).withdraw(fleetBalance, msg.sender, address(this));
        
        // Repay borrow
        borrowedAsset.forceApprove(address(aaveV3Pool), fleetBalance);
        aaveV3Pool.repay(address(borrowedAsset), fleetBalance, 2, address(this));
        
        // Withdraw collateral
        aaveV3Pool.withdraw(address(collateralAsset), amount, address(this));
    }

    function _validateBoardData(bytes calldata data) pure internal override {
        require(data.length == 32, "Invalid borrow amount");
    }

    function _withdrawableTotalAssets() internal view override returns (uint256) {
        return totalAssets();
    }

    function _validateDisembarkData(bytes calldata) internal pure override {
        // No validation needed for disembark data
    }

    function _harvest(bytes calldata) internal override returns (address[] memory rewardTokens, uint256[] memory rewardAmounts) {
        address[] memory assets = new address[](2);
        assets[0] = collateralAToken;
        assets[1] = borrowedAToken;
        
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