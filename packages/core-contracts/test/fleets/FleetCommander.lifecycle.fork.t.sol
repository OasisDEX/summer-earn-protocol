// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";

import "../../src/contracts/arks/CompoundV3Ark.sol";
import "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/contracts/arks/MorphoArk.sol";
import "../../src/contracts/arks/MetaMorphoArk.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/events/IArkEvents.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {IMorpho, Id, MarketParams, IMorphoBase} from "../../src/interfaces/morpho-blue/IMorpho.sol";
import {IMetaMorpho, IMetaMorphoBase} from "../../src/interfaces/meta-morpho/IMetaMorpho.sol";

/**
 * @title Lifecycle test suite for FleetCommander
 * @dev Test suite of full lifecycle tests EG Deposit -> Rebalance -> ForceWithdraw
 */
contract LifecycleTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    // Arks
    CompoundV3Ark public compoundArk;
    AaveV3Ark public aaveArk;
    MorphoArk public morphoArk;
    MetaMorphoArk public metaMorphoArk;

    // External contracts
    IComet public usdcCompoundCometContract;
    IPoolV3 public aaveV3PoolContract;
    IERC20 public usdcTokenContract;
    IMorpho public morphoContract;
    IMetaMorpho public metaMorphoContract;

    // Constants
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant AAVE_V3_POOL_ADDRESS =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant COMPOUND_USDC_COMET_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant MORPHO_ADDRESS =
        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    Id public constant MORPHO_MARKET_ID =
        Id.wrap(
            0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49
        );
    uint256 constant FORK_BLOCK = 20376149;

    function setUp() public {
        console.log("Setting up LifecycleTest");

        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        initializeFleetCommanderWithoutArks(USDC_ADDRESS);
        setupExternalContracts();
        setupArks();
        addArksToFleetCommander();
        grantPermissions();

        logSetupInfo();
    }

    function setupExternalContracts() internal {
        usdcTokenContract = IERC20(USDC_ADDRESS);
        aaveV3PoolContract = IPoolV3(AAVE_V3_POOL_ADDRESS);
        usdcCompoundCometContract = IComet(COMPOUND_USDC_COMET_ADDRESS);
        morphoContract = IMorpho(MORPHO_ADDRESS);
        metaMorphoContract = IMetaMorpho(METAMORPHO_ADDRESS);
    }

    function setupArks() internal {
        ArkParams memory arkParams = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(usdcTokenContract),
            maxAllocation: type(uint256).max
        });
        aaveArk = new AaveV3Ark(address(aaveV3PoolContract), arkParams);
        compoundArk = new CompoundV3Ark(
            address(usdcCompoundCometContract),
            arkParams
        );

        MarketParams memory morphoMarketParams = morphoContract
            .idToMarketParams(MORPHO_MARKET_ID);
        morphoArk = new MorphoArk(
            MORPHO_ADDRESS,
            morphoMarketParams,
            arkParams
        );

        metaMorphoArk = new MetaMorphoArk(METAMORPHO_ADDRESS, arkParams);
    }

    function addArksToFleetCommander() internal {
        address[] memory arks = new address[](4);
        arks[0] = address(compoundArk);
        arks[1] = address(aaveArk);
        arks[2] = address(morphoArk);
        arks[3] = address(metaMorphoArk);
        vm.prank(governor);
        fleetCommander.addArks(arks);
    }

    function grantPermissions() internal {
        vm.startPrank(governor);
        compoundArk.grantCommanderRole(address(fleetCommander));
        aaveArk.grantCommanderRole(address(fleetCommander));
        morphoArk.grantCommanderRole(address(fleetCommander));
        metaMorphoArk.grantCommanderRole(address(fleetCommander));
        bufferArk.grantCommanderRole(address(fleetCommander));
        accessManager.grantKeeperRole(keeper);
        vm.stopPrank();
    }

    function logSetupInfo() internal view {
        console.log("aave ark:", address(aaveArk));
        console.log("compound ark:", address(compoundArk));
        console.log("morpho ark:", address(morphoArk));
        console.log("metamorpho ark:", address(metaMorphoArk));
        console.log("buffer ark:", address(bufferArk));
        console.log("fleet commander:", address(fleetCommander));
    }

    function test_DepositRebalanceForceWithdrawFork() public {
        // Arrange
        uint256 totalDeposit = 4000 * 10 ** 6; // 4000 USDC
        uint256 userDeposit = totalDeposit / 4; // 1000 USDC per ark
        uint256 depositCap = totalDeposit;
        uint256 minBufferBalance = 0;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Set deposit cap
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mint tokens for user
        deal(address(usdcTokenContract), mockUser, totalDeposit);

        // User deposits
        depositForUser(mockUser, totalDeposit);

        // Rebalance funds to all Arks
        RebalanceData[] memory rebalanceData = new RebalanceData[](4);
        rebalanceData[0] = RebalanceData({
            fromArk: address(bufferArk),
            toArk: address(compoundArk),
            amount: userDeposit
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(bufferArk),
            toArk: address(aaveArk),
            amount: userDeposit
        });
        rebalanceData[2] = RebalanceData({
            fromArk: address(bufferArk),
            toArk: address(morphoArk),
            amount: userDeposit
        });
        rebalanceData[3] = RebalanceData({
            fromArk: address(bufferArk),
            toArk: address(metaMorphoArk),
            amount: userDeposit
        });

        // Advance time to move past cooldown window
        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        metaMorphoArk.poke();

        // Advance time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        // Accrue interest for Morpho
        morphoContract.accrueInterest(
            morphoContract.idToMarketParams(MORPHO_MARKET_ID)
        );

        // Check total assets and rates
        checkAssetsAndRates();

        // User withdraws
        withdrawForUser(mockUser, totalDeposit);

        // Assert
        assertApproxEqAbs(
            fleetCommander.totalAssets(),
            0,
            1000, // Allow for small rounding errors
            "Total assets should be close to 0 after withdrawals"
        );
    }

    function depositForUser(address user, uint256 amount) internal {
        vm.startPrank(user);
        usdcTokenContract.approve(address(fleetCommander), amount);
        uint256 previewShares = fleetCommander.previewDeposit(amount);
        uint256 depositedShares = fleetCommander.deposit(amount, user);
        assertEq(
            previewShares,
            depositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleetCommander.balanceOf(user),
            amount,
            "User balance should be equal to deposit"
        );
        vm.stopPrank();
    }

    function withdrawForUser(
        address user,
        uint256 expectedMinimumAmount
    ) internal {
        vm.startPrank(user);
        uint256 userShares = fleetCommander.balanceOf(user);
        uint256 userAssets = fleetCommander.previewRedeem(userShares);
        console.log("User shares:", userShares);
        console.log("User assets:", userAssets);
        fleetCommander.forceWithdraw(userAssets, user, user);

        assertEq(fleetCommander.balanceOf(user), 0, "User balance should be 0");
        assertGe(
            usdcTokenContract.balanceOf(user),
            expectedMinimumAmount,
            "User should receive at least the expected minimum assets"
        );
        vm.stopPrank();
    }

    function checkAssetsAndRates() internal view {
        console.log("Compound Ark assets   :", compoundArk.totalAssets());
        console.log("Aave Ark assets       :", aaveArk.totalAssets());
        console.log("Morpho Ark assets     :", morphoArk.totalAssets());
        console.log("MetaMorpho Ark assets :", metaMorphoArk.totalAssets());

        console.log("Compound Ark rate     :", compoundArk.rate());
        console.log("Aave Ark rate         :", aaveArk.rate());
        console.log("Morpho Ark rate       :", morphoArk.rate());
        console.log("MetaMorpho Ark rate   :", metaMorphoArk.rate());

        assertTrue(
            compoundArk.totalAssets() > 1000 * 10 ** 6,
            "Compound Ark assets should have increased"
        );
        assertTrue(
            aaveArk.totalAssets() > 1000 * 10 ** 6,
            "Aave Ark assets should have increased"
        );
        assertTrue(
            morphoArk.totalAssets() > 1000 * 10 ** 6,
            "Morpho Ark assets should have increased"
        );
        assertTrue(
            metaMorphoArk.totalAssets() > 1000 * 10 ** 6,
            "MetaMorpho Ark assets should have increased"
        );

        assertTrue(
            compoundArk.rate() > 0,
            "Compound Ark rate should be greater than zero"
        );
        assertTrue(
            aaveArk.rate() > 0,
            "Aave Ark rate should be greater than zero"
        );
        assertTrue(
            morphoArk.rate() > 0,
            "Morpho Ark rate should be greater than zero"
        );
        assertTrue(
            metaMorphoArk.rate() > 0,
            "MetaMorpho Ark rate should be greater than zero"
        );
    }
}
