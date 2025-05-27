// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/AaveV3CarryTradeArk.sol";
import {ICarryTradeArk} from "../../src/interfaces/ICarryTradeArk.sol";

import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ERC20, ERC4626, IERC20, IERC4626, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract TestAaveV3BorrowArk is AaveV3CarryTradeArk {
    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        address _poolAddressesProvider,
        address _borrowedAsset,
        address _fleet,
        uint256 _maxLtv,
        uint256 _slippage,
        ArkParams memory _params
    )
        AaveV3CarryTradeArk(
            _aaveV3Pool,
            _rewardsController,
            _poolAddressesProvider,
            _borrowedAsset,
            _fleet,
            _maxLtv,
            _slippage,
            _params
        )
    {}
}
interface IPoolConfigurator {
    function setSupplyCap(address asset, uint256 newSupplyCap) external;
}
contract AaveV3BorrowArkTest is Test, ArkTestBase {
    using SafeERC20 for IERC20;

    TestAaveV3BorrowArk public ark;
    IPoolV3 public aaveV3Pool;

    address public constant AAVE_V3_POOL =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant REWARDS_CONTROLLER =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
    address public constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    address public constant POOL_CONFIGURATOR =
        0x64b761D848206f447Fe2dd461b0c635Ec39EbB27;

    // Mainnet token addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 public weth;
    IERC20 public usdc;
    IERC4626 public wethFleet;
    IERC4626 public usdcFleet;
    address usdcBufferArkAddress;
    address wethBufferArkAddress;
    // eth price 3400
    uint256 public forkBlock = 21745576;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

        (
            address usdcFleetCommanderAddress,
            address _usdcBufferArkAddress
        ) = setupFleetCommanderWithBufferArk(USDC, "USDC Fleet");
        (
            address wethFleetCommanderAddress,
            address _wethBufferArkAddress
        ) = setupFleetCommanderWithBufferArk(WETH, "WETH Fleet");
        usdcBufferArkAddress = _usdcBufferArkAddress;
        wethBufferArkAddress = _wethBufferArkAddress;
        commander = wethFleetCommanderAddress;

        weth = IERC20(WETH);
        usdc = IERC20(USDC);

        // Deploy a mock wethFleet
        wethFleet = IERC4626(wethFleetCommanderAddress);
        usdcFleet = IERC4626(usdcFleetCommanderAddress);

        aaveV3Pool = IPoolV3(AAVE_V3_POOL);

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
            address(usdcFleet),
            7000,
            100,
            params
        );

        // Setup permissions
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(ark),
            address(wethFleetCommanderAddress)
        );
        accessManager.grantKeeperRole(address(ark), address(keeper));
        accessManager.grantCuratorRole(
            address(wethFleetCommanderAddress),
            address(curator)
        );
        IFleetCommanderConfigProvider(wethFleetCommanderAddress).addArk(
            address(ark)
        );
        vm.stopPrank();

        vm.prank(curator);
        ark.whitelistRouter(0x6A000F20005980200259B80c5102003040001068, true);

        address variableDebtToken = IPoolV3(AAVE_V3_POOL)
            .getReserveData(USDC)
            .variableDebtTokenAddress;
        address aToken = IPoolV3(AAVE_V3_POOL)
            .getReserveData(WETH)
            .aTokenAddress;
        console.log("variableDebtToken", variableDebtToken);
        console.log("aToken", aToken);
        address priceOracle = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER)
            .getPriceOracle();

        vm.makePersistent(address(ark));
        vm.makePersistent(address(wethFleet));
        vm.makePersistent(address(usdcFleet));
        vm.makePersistent(address(weth));
        vm.makePersistent(address(usdc));
        vm.makePersistent(AAVE_V3_POOL);
        vm.makePersistent(REWARDS_CONTROLLER);
        vm.makePersistent(POOL_ADDRESSES_PROVIDER);
        vm.makePersistent(address(accessManager));
        vm.makePersistent(address(configurationManager));
        vm.makePersistent(address(_usdcBufferArkAddress));
        vm.makePersistent(address(_wethBufferArkAddress));
        vm.makePersistent(address(variableDebtToken));
        vm.makePersistent(address(aToken));
        vm.makePersistent(address(priceOracle));

        vm.label(address(ark), "ark");
        vm.label(address(wethFleet), "wethFleet");
        vm.label(address(usdcFleet), "usdcFleet");
        vm.label(address(weth), "weth");
        vm.label(address(usdc), "usdc");
        vm.label(address(AAVE_V3_POOL), "aaveV3Pool");
        vm.label(address(REWARDS_CONTROLLER), "rewardsController");
        vm.label(address(POOL_ADDRESSES_PROVIDER), "poolAddressesProvider");
        vm.label(address(variableDebtToken), "variableDebtToken");
        vm.label(address(aToken), "aToken");
        vm.label(address(priceOracle), "priceOracle");
        vm.label(address(commander), "commander");
        vm.label(address(keeper), "keeper");
        vm.label(address(governor), "governor");
        vm.label(address(accessManager), "accessManager");
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
            IERC4626(usdcFleet).balanceOf(address(ark)),
            0,
            "commander should have a balance in the usdcFleet"
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
        bool closePosition = false;

        // Act
        ark.disembark(
            collateralAmount,
            abi.encode(
                ICarryTradeArk.DisembarkData({
                    closePosition: closePosition,
                    repayAmount: repayAmount,
                    swapData: ICarryTradeArk.SwapData({
                        router: address(0),
                        swapCalldata: "",
                        minAmountOut: 0
                    })
                })
            )
        );
        vm.stopPrank();

        // Assert
        assertEq(ark.totalAssets(), 0);
        assertEq(weth.balanceOf(commander), collateralAmount);
    }

    // 1. what if we swap too little of borrowed
    // 2. what if there's borrowed dust left
    function test_Disembark_ClosePosition() public {
        vm.rollFork(22573641);

        // Arrange
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC
        // function setSupplyCap(address asset, uint256 newSupplyCap) external override onlyRiskOrPoolAdmins
        vm.prank(0x46Ab47bA01EF627ce47F2ED61C9482794a6109c4);
        IPoolConfigurator(POOL_CONFIGURATOR).setSupplyCap(address(WETH), 0);

        deal(WETH, commander, collateralAmount * 10000);

        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));

        bool closePosition = true;
        bytes
            memory swapCalldata = hex"e3ead59e000000000000000000000000000010036c0190e009a000d0fc3541100a07380a000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000004a732430000000000000000000000000000000000000000000000000068f1033789f34f00000000000000000000000000000000000000000000000000690be78b63e8063e76c365c2ba42e0a35a63ae8f142f86000000000000000000000000015872e6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002809995855c00494d039ab6792f18e368e530dff9310000014000840000ff00000700000000000000000000000000000000000000000000000000000000f196187f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000020c49ba5e353f7000003e800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000004a732430000000000000000000000000000000000000000ffff9a5889f795069a41a8a300000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010036c0190e009a000d0fc3541100a07380ac02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000004000000004ff00000500000000000000000000000000000000000000000000000000000000d0e30db0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000690be78b63e806";
        address router = 0x6A000F20005980200259B80c5102003040001068;
        vm.warp(block.timestamp + 180 days);
        // debt == 1046766215
        // accrue 1% interest - there will be leftover usdc
        deal(
            address(usdc),
            address(usdcBufferArkAddress),
            (borrowAmount * 110) / 100
        );
        // Act
        ark.disembark(
            collateralAmount,
            abi.encode(
                ICarryTradeArk.DisembarkData({
                    closePosition: closePosition,
                    repayAmount: 1,
                    swapData: ICarryTradeArk.SwapData({
                        router: router,
                        swapCalldata: swapCalldata,
                        minAmountOut: 0 // In production, this should be calculated
                    })
                })
            )
        );
        vm.stopPrank();

        // Assert
        assertEq(ark.totalAssets(), 0, "total assets should be 0");
        assertEq(weth.balanceOf(address(ark)), 0, "weth balance should be 0");
        assertEq(
            IERC4626(wethFleet).balanceOf(address(ark)),
            0,
            "weth fleet balance should be 0"
        );
        assertEq(
            IERC20(ark.variableDebtToken()).balanceOf(address(ark)),
            0,
            "variable debt token balance should be 0"
        );
        assertEq(
            IERC20(ark.aToken()).balanceOf(address(ark)),
            0,
            "a token balance should be 0"
        );
        assertEq(
            IERC20(ark.collateralAsset()).balanceOf(address(ark)),
            0,
            "collateral asset balance should be 0"
        );
        assertEq(
            IERC20(ark.borrowedAsset()).balanceOf(address(ark)),
            0,
            "borrowed asset balance should be 0"
        );
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
        vm.stopPrank();
        vm.prank(keeper);
        ark.upkeep(
            abi.encode(
                ICarryTradeArk.UpkeepData({
                    action: ICarryTradeArk.UpkeepAction.REBALANCE,
                    actionData: ""
                })
            )
        );
        uint256 debtAfter = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );

        // Verify no changes were made since position is safe
        assertEq(
            debtBefore,
            debtAfter,
            "Should not rebalance when position is safe"
        );
    }

    function test_RebalancePosition_WhenPriceDropsSignificantly() public {
        // Setup initial position
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 2500 * 1e6; // 1200 USDC
        deal(WETH, commander, collateralAmount);
        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));
        deal(address(usdc), address(wethFleet), (borrowAmount * 102) / 100);
        // Simulate significant ETH price drop by moving to a known block with lower ETH price
        // drop from 2800 to 2600
        vm.rollFork(21916632); // Choose a block number where ETH price was significantly lower
        // Get state before rebalance
        uint256 debtBefore = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        deal(address(usdc), address(wethFleet), (borrowAmount * 105) / 100);
        uint256 totalAssetsBeforeRebalance = ark.totalAssets();
        vm.stopPrank();
        // Rebalance position
        vm.prank(keeper);
        ark.upkeep(
            abi.encode(
                ICarryTradeArk.UpkeepData({
                    action: ICarryTradeArk.UpkeepAction.REBALANCE,
                    actionData: ""
                })
            )
        );
        uint256 totalAssetsAfterRebalance = ark.totalAssets();
        assertEq(
            totalAssetsBeforeRebalance,
            totalAssetsAfterRebalance,
            "Total assets should not change"
        );
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
    }

    function test_RebalancePosition_NoActionWhenSlightlyUnsafe() public {
        // Setup position that's just barely above maxLtv
        uint256 collateralAmount = 1 ether;
        uint256 borrowAmount = 1300 * 1e6; // Amount that puts LTV just above max

        deal(WETH, commander, collateralAmount);
        vm.startPrank(commander);
        weth.approve(address(ark), collateralAmount);
        ark.board(collateralAmount, abi.encode(borrowAmount));
        vm.stopPrank();
        // Simulate small price movement
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        uint256 debtBefore = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );
        vm.prank(keeper);
        ark.upkeep(
            abi.encode(
                ICarryTradeArk.UpkeepData({
                    action: ICarryTradeArk.UpkeepAction.REBALANCE,
                    actionData: ""
                })
            )
        );
        uint256 debtAfter = IERC20(ark.variableDebtToken()).balanceOf(
            address(ark)
        );

        // If position is only slightly unsafe (less than safety margin), no action should be taken
        assertEq(
            debtBefore,
            debtAfter,
            "Should not rebalance for small LTV deviation"
        );
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
