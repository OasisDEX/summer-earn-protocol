// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/MorphoArk.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {IMorpho, Id, MarketParams, IMorphoBase} from "morpho-blue/interfaces/IMorpho.sol";
import {IMetaMorpho} from "metamorpho/interfaces/IMetaMorpho.sol";

contract MorphoArkTestFork is Test, IArkEvents {
    MorphoArk public ark;
    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    IConfigurationManager configurationManager;
    IProtocolAccessManager accessManager;
    address public constant MORPHO_ADDRESS =
        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WBTC_ADDRESS =
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    Id public constant MARKET_ID =
        Id.wrap(
            0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49
        );

    IMorpho public morpho;
    IERC20 public usdc;

    uint256 forkBlock = 20376149;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        morpho = IMorpho(MORPHO_ADDRESS);
        usdc = IERC20(USDC_ADDRESS);

        accessManager = new ProtocolAccessManager(governor);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: USDC_ADDRESS,
            maxAllocation: type(uint256).max
        });

        ark = new MorphoArk(MORPHO_ADDRESS, MARKET_ID, params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        vm.stopPrank();
    }

    function test_Constructor_MorphoArk_fork() public {
        // Arrange
        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(usdc),
            maxAllocation: 1000
        });

        // Act & Assert
        vm.expectRevert(abi.encodeWithSignature("InvalidMorphoAddress()"));
        new MorphoArk(address(0), Id.wrap(0), params);

        vm.expectRevert(abi.encodeWithSignature("InvalidMorphoAddress()"));
        new MorphoArk(address(0), MARKET_ID, params);

        vm.expectRevert(abi.encodeWithSignature("InvalidMarketId()"));
        new MorphoArk(MORPHO_ADDRESS, Id.wrap(0), params);

        MorphoArk newArk = new MorphoArk(MORPHO_ADDRESS, MARKET_ID, params);
        assertTrue(
            newArk.maxAllocation() == 1000,
            "Max allocation should be set"
        );
        assertTrue(
            Id.unwrap(newArk.marketId()) == Id.unwrap(MARKET_ID),
            "Market ID should be set"
        );
        assertTrue(newArk.totalAssets() == 0, "Total assets should be zero");
        assertTrue(
            address(newArk.MORPHO()) == MORPHO_ADDRESS,
            "Morpho address should be set"
        );
    }

    function test_Board_MorphoArk_fork() public {
        vm.prank(governor);
        ark.grantCommanderRole(commander);

        // Arrange
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        // Expect the supply call to Morpho
        vm.expectCall(
            MORPHO_ADDRESS,
            abi.encodeWithSelector(
                IMorphoBase.supply.selector,
                morpho.idToMarketParams(MARKET_ID),
                amount,
                0,
                address(ark),
                ""
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, USDC_ADDRESS, amount);

        // Act
        ark.board(amount);
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertEq(
            assetsAfterDeposit,
            amount - 1,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        morpho.accrueInterest(morpho.idToMarketParams(MARKET_ID));

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual > assetsAfterDeposit,
            "Assets should increase after accrual"
        );

        // Check rate
        uint256 currentRate = ark.rate();
        assertTrue(
            currentRate == 46471864329936000000000000,
            "Rate should be equal to 4.647% at that exact block"
        );
    }

    function test_Disembark_MorphoArk_fork() public {
        // First, board some assets
        test_Board_MorphoArk_fork();

        uint256 initialBalance = usdc.balanceOf(commander);
        uint256 amountToWithdraw = 500 * 10 ** 6; // 500 USDC

        vm.prank(commander);

        // Expect the withdraw call to Morpho
        vm.expectCall(
            MORPHO_ADDRESS,
            abi.encodeWithSelector(
                IMorphoBase.withdraw.selector,
                morpho.idToMarketParams(MARKET_ID),
                amountToWithdraw,
                0,
                address(ark),
                address(ark)
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, USDC_ADDRESS, amountToWithdraw);

        vm.prank(commander);
        ark.disembark(amountToWithdraw, commander);

        uint256 finalBalance = usdc.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = ark.totalAssets();

        assertTrue(
            remainingAssets > 1000 * 10 ** 6 - amountToWithdraw,
            "Remaining assets should more than initial balance minus withdrawn amount (accounting the accrued interest)"
        );
    }

    function test_Rate_Zero_fork() public {
        // Arrange
        Market memory market = Market({
            totalSupplyShares: 0,
            totalSupplyAssets: 0,
            totalBorrowShares: 0,
            totalBorrowAssets: 0,
            fee: 0,
            lastUpdate: 0
        });
        vm.mockCall(
            MORPHO_ADDRESS,
            abi.encodeWithSelector(IMorpho.market.selector, MARKET_ID),
            abi.encode(market)
        );

        // Act
        uint256 rate = ark.rate();

        // Assert
        assertTrue(rate == 0, "Rate should be zero");
    }
}
