// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/AaveV3BorrowArk.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20, ERC4626, IERC20, IERC4626, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract TestAaveV3BorrowArk is AaveV3BorrowArk {
    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        address _borrowedAsset,
        address _fleet,
        ArkParams memory _params
    )
        AaveV3BorrowArk(
            _aaveV3Pool,
            _rewardsController,
            _borrowedAsset,
            _fleet,
            _params
        )
    {}
}

contract AaveV3BorrowArkTest is Test, ArkTestBase {
    using SafeERC20 for IERC20;

    TestAaveV3BorrowArk public ark;

    address public constant AAVE_V3_POOL =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant REWARDS_CONTROLLER =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;

    // Mainnet token addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 public weth;
    IERC20 public usdc;
    IERC4626 public mockFleet;

    uint256 public forkBlock = 20006596;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

        weth = IERC20(WETH);
        usdc = IERC20(USDC);

        // Deploy a mock fleet
        mockFleet = IERC4626(deployMockFleet(USDC));

        ArkParams memory params = ArkParams({
            name: "WETH-USDC BorrowArk",
            details: "Borrow USDC against WETH collateral",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new TestAaveV3BorrowArk(
            AAVE_V3_POOL,
            REWARDS_CONTROLLER,
            USDC,
            address(mockFleet),
            params
        );

        // Setup permissions
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();
    }

    function test_Board_WithBorrow() public {
        // Arrange
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC

        deal(WETH, commander, collateralAmount);

        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);

        // Act
        ark.board(collateralAmount, abi.encode(borrowAmount));
        vm.stopPrank();

        // Assert
        assertEq(
            ark.totalAssets(),
            collateralAmount,
            "total assets should be equal to collateral amount"
        );
        assertGt(
            IERC4626(mockFleet).balanceOf(address(ark)),
            0,
            "commander should have a balance in the fleet"
        );
    }

    function test_Disembark() public {
        // Arrange - First board some assets
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC

        deal(WETH, commander, collateralAmount);

        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));

        uint256 repayAmount = 1000 * 1e6;

        // Act
        ark.disembark(collateralAmount, abi.encode(repayAmount));
        vm.stopPrank();

        // Assert
        assertEq(ark.totalAssets(), 0);
        assertEq(weth.balanceOf(commander), collateralAmount);
    }

    function deployMockFleet(address _asset) internal returns (address) {
        return address(new MockFleet(_asset));
    }
}

contract MockFleet is ERC4626 {
    constructor(
        address assetAddr
    ) ERC4626(IERC20(assetAddr)) ERC20("Mock Fleet", "MFLT") {}
}
