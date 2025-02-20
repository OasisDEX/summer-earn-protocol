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
        address _poolAddressesProvider,
        address _borrowedAsset,
        address _fleet,
        ArkParams memory _params,
        uint256 _maxLtv
    )
        AaveV3BorrowArk(
            _aaveV3Pool,
            _rewardsController,
            _poolAddressesProvider,
            _borrowedAsset,
            _fleet,
            _params,
            _maxLtv
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
    address public constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

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
            POOL_ADDRESSES_PROVIDER,
            USDC,
            address(mockFleet),
            params,
            7000
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

    function test_RebalancePosition_WhenSafe() public {
        // Setup initial position
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC - safe amount given ETH/USDC price

        // Setup position
        deal(WETH, commander, collateralAmount);
        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));

        // Try to rebalance
        uint256 debtBefore = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        ark.rebalancePosition();
        uint256 debtAfter = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );

        // Verify no changes were made since position is safe
        assertEq(
            debtBefore,
            debtAfter,
            "Should not rebalance when position is safe"
        );
        vm.stopPrank();
    }

    function test_RebalancePosition_WhenUnsafe() public {
        // Setup initial position with high LTV
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 2800 * 1e6; // 1500 USDC - higher amount to create unsafe position

        // Setup position
        deal(WETH, commander, collateralAmount);
        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));

        // Simulate price drop to make position unsafe
        // We'll do this by manipulating the fork to a block where ETH price was lower
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 days);

        // Get initial state
        uint256 debtBefore = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        uint256 ltvBefore = ark.currentLtv();

        // Ensure position is actually unsafe
        assertGt(
            ltvBefore,
            ark.maxLtv(),
            "Position should be unsafe before rebalance"
        );

        // Rebalance position
        ark.rebalancePosition();

        // // Verify position is now safe
        // uint256 debtAfter = IERC20(ark.debtToken()).balanceOf(address(ark));
        // uint256 ltvAfter = ark.currentLtv();

        // assertLt(debtAfter, debtBefore, "Debt should be reduced");
        // assertLe(ltvAfter, ark.maxLtv(), "Position should be safe after rebalance");
        // assertGe(ltvAfter, ark.maxLtv() - ark.SAFETY_MARGIN(), "LTV should be near target");
        // vm.stopPrank();
    }

    function test_RebalancePosition_WhenPriceDropsSignificantly() public {
        // Setup initial position
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1200 * 1e6; // 1200 USDC

        deal(WETH, commander, collateralAmount);
        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));

        // Simulate significant ETH price drop by moving to a known block with lower ETH price
        vm.rollFork(19_000_000); // Choose a block number where ETH price was significantly lower

        // Get state before rebalance
        uint256 debtBefore = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        uint256 ltvBefore = ark.currentLtv();

        // Rebalance position
        ark.rebalancePosition();

        // Verify position is safe and properly rebalanced
        uint256 debtAfter = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        uint256 ltvAfter = ark.currentLtv();

        assertLt(debtAfter, debtBefore, "Debt should be reduced");
        assertLe(
            ltvAfter,
            ark.maxLtv(),
            "Position should be safe after rebalance"
        );
        vm.stopPrank();
    }

    function test_RebalancePosition_NoActionWhenSlightlyUnsafe() public {
        // Setup position that's just barely above maxLtv
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1300 * 1e6; // Amount that puts LTV just above max

        deal(WETH, commander, collateralAmount);
        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));

        // Simulate small price movement
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        uint256 debtBefore = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        ark.rebalancePosition();
        uint256 debtAfter = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );

        // If position is only slightly unsafe (less than safety margin), no action should be taken
        assertEq(
            debtBefore,
            debtAfter,
            "Should not rebalance for small LTV deviation"
        );
        vm.stopPrank();
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
