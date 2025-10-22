// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/contracts/arks/CompoundV3Ark.sol";
import "../../src/contracts/arks/MorphoVaultArk.sol";
import "../../src/contracts/arks/MorphoArk.sol";
import "../../src/events/IArkEvents.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/ERC4626Ark.sol";
import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title Lifecycle test suite for FleetCommander on Base network
 * @dev Test suite of full lifecycle tests for USDC fleet using all available Morpho vaults
 */
contract BaseLifecycleTest is Test, TestHelpers, FleetCommanderTestBase {
    // USDC Fleet Arks - All available Morpho vaults on Base
    CompoundV3Ark public usdcCompoundArk;
    AaveV3Ark public usdcAaveArk;
    MorphoVaultArk public usdcMoonwellFlagshipArk;
    MorphoVaultArk public usdcGauntletCoreArk;
    MorphoVaultArk public usdcGauntletPrimeArk;
    MorphoVaultArk public usdcRe7Ark;
    MorphoVaultArk public usdcSteakhouseArk;
    MorphoVaultArk public usdcSparkArk;
    MorphoVaultArk public usdcSeamlessArk;
    MorphoVaultArk public usdcSteakhouseHighYieldArk;
    MorphoVaultArk public usdcExtrafiXLendArk;
    MorphoVaultArk public usdcUniversalArk;
    MorphoVaultArk public usdcClearstarHighYieldArk;
    MorphoVaultArk public usdcClearstarReactorOpenEdenBoostedArk;
    MorphoVaultArk public usdcGauntletFrontierArk;
    ERC4626Ark public usdcFluidERC4626Ark;
    ERC4626Ark public usdcEulerBaseERC4626Ark;
    BufferArk public usdcBufferArk;

    address[] public usdcArks;

    // External contracts
    IComet public usdcCompoundCometContract;
    IPoolV3 public aaveV3PoolContract;
    IERC20 public usdcTokenContract;
    IMorpho public morphoContract;
    IERC4626 public fluidUsdcVault;
    IERC4626 public eulerBaseUsdcVault;

    // Constants - Base network addresses
    address public constant USDC_ADDRESS =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant AAVE_V3_POOL_ADDRESS =
        0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address public constant COMPOUND_USDC_COMET_ADDRESS =
        0xb125E6687d4313864e53df431d5425969c15Eb2F;
    address public constant COMET_REWARDS =
        0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address public constant AAVE_V3_REWARDS_CONTROLLER =
        0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;
    address public constant MORPHO_ADDRESS =
        0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842;
    address public constant MORPHO_URD_FACTORY =
        0x7276454fc1cf9C408deeed722fd6b5E7A4CA25D8;

    // Base Morpho USDC vault addresses
    address public constant MOONWELL_FLAGSHIP_USDC =
        0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca;
    address public constant GAUNTLET_USDC_CORE =
        0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12;
    address public constant GAUNTLET_USDC_PRIME =
        0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address public constant RE7_USDC =
        0x12AFDeFb2237a5963e7BAb3e2D46ad0eee70406e;
    address public constant STEAKHOUSE_USDC =
        0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address public constant SPARK_USDC =
        0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;
    address public constant SEAMLESS_USDC =
        0x616a4E1db48e22028f6bbf20444Cd3b8e3273738;
    address public constant STEAKHOUSE_HIGH_YIELD_USDC =
        0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F;
    address public constant EXTRAFI_XLEND_USDC =
        0x23479229e52Ab6aaD312D0B03DF9F33B46753B5e;
    address public constant UNIVERSAL_USDC =
        0xB7890CEE6CF4792cdCC13489D36D9d42726ab863;
    address public constant CLEARSTAR_HIGH_YIELD_USDC =
        0xE74c499fA461AF1844fCa84204490877787cED56;
    address public constant CLEARSTAR_REACTOR_OPENEDEN_BOOSTED_USDC =
        0x1D3b1Cd0a0f242d598834b3F2d126dC6bd774657;
    address public constant GAUNTLET_USDC_FRONTIER =
        0x236919F11ff9eA9550A4287696C2FC9e18E6e890;

    // ERC4626 vaults
    address public constant FLUID_USDC_VAULT_ADDRESS =
        0xf42f5795D9ac7e9D757dB633D693cD548Cfd9169;
    address public constant EULER_BASE_USDC_VAULT_ADDRESS =
        0x085178078796Da17B191f9081b5E2fCCc79A7eE7;

    uint256 constant FORK_BLOCK = 33809569; // Base network fork block

    // Fleet Commander
    IFleetCommander public usdcFleetCommander;

    function setUp() public {
        console.log("Setting up BaseLifecycleTest");

        vm.createSelectFork(vm.rpcUrl("base"), FORK_BLOCK);

        uint256 initialTipRate = 0;
        setupExternalContracts();
        setupFleetCommander(initialTipRate);
        setupArks();
        addArksToFleetCommander();

        logSetupInfo();
        setupLabels();
    }

    function setupLabels() internal {
        vm.label(USDC_ADDRESS, "USDC");
        vm.label(AAVE_V3_POOL_ADDRESS, "AAVE_V3_POOL");
        vm.label(COMPOUND_USDC_COMET_ADDRESS, "COMPOUND_USDC_COMET");
        vm.label(COMET_REWARDS, "COMET_REWARDS");
        vm.label(AAVE_V3_REWARDS_CONTROLLER, "AAVE_V3_REWARDS_CONTROLLER");
        vm.label(MORPHO_ADDRESS, "MORPHO");
        vm.label(MORPHO_URD_FACTORY, "MORPHO_URD_FACTORY");

        // Label all Morpho vaults
        vm.label(MOONWELL_FLAGSHIP_USDC, "MOONWELL_FLAGSHIP_USDC");
        vm.label(GAUNTLET_USDC_CORE, "GAUNTLET_USDC_CORE");
        vm.label(GAUNTLET_USDC_PRIME, "GAUNTLET_USDC_PRIME");
        vm.label(RE7_USDC, "RE7_USDC");
        vm.label(STEAKHOUSE_USDC, "STEAKHOUSE_USDC");
        vm.label(SPARK_USDC, "SPARK_USDC");
        vm.label(SEAMLESS_USDC, "SEAMLESS_USDC");
        vm.label(STEAKHOUSE_HIGH_YIELD_USDC, "STEAKHOUSE_HIGH_YIELD_USDC");
        vm.label(EXTRAFI_XLEND_USDC, "EXTRAFI_XLEND_USDC");
        vm.label(UNIVERSAL_USDC, "UNIVERSAL_USDC");
        vm.label(CLEARSTAR_HIGH_YIELD_USDC, "CLEARSTAR_HIGH_YIELD_USDC");
        vm.label(
            CLEARSTAR_REACTOR_OPENEDEN_BOOSTED_USDC,
            "CLEARSTAR_REACTOR_OPENEDEN_BOOSTED_USDC"
        );
        vm.label(GAUNTLET_USDC_FRONTIER, "GAUNTLET_USDC_FRONTIER");

        // Label ERC4626 vaults
        vm.label(FLUID_USDC_VAULT_ADDRESS, "FLUID_USDC_VAULT");
        vm.label(EULER_BASE_USDC_VAULT_ADDRESS, "EULER_BASE_USDC_VAULT");

        // Label Arks
        vm.label(address(usdcCompoundArk), "USDC_COMPOUND_ARK");
        vm.label(address(usdcAaveArk), "USDC_AAVE_ARK");
        vm.label(
            address(usdcMoonwellFlagshipArk),
            "USDC_MOONWELL_FLAGSHIP_ARK"
        );
        vm.label(address(usdcGauntletCoreArk), "USDC_GAUNTLET_CORE_ARK");
        vm.label(address(usdcGauntletPrimeArk), "USDC_GAUNTLET_PRIME_ARK");
        vm.label(address(usdcRe7Ark), "USDC_RE7_ARK");
        vm.label(address(usdcSteakhouseArk), "USDC_STEAKHOUSE_ARK");
        vm.label(address(usdcSparkArk), "USDC_SPARK_ARK");
        vm.label(address(usdcSeamlessArk), "USDC_SEAMLESS_ARK");
        vm.label(
            address(usdcSteakhouseHighYieldArk),
            "USDC_STEAKHOUSE_HIGH_YIELD_ARK"
        );
        vm.label(address(usdcExtrafiXLendArk), "USDC_EXTRAFI_XLEND_ARK");
        vm.label(address(usdcUniversalArk), "USDC_UNIVERSAL_ARK");
        vm.label(
            address(usdcClearstarHighYieldArk),
            "USDC_CLEARSTAR_HIGH_YIELD_ARK"
        );
        vm.label(
            address(usdcClearstarReactorOpenEdenBoostedArk),
            "USDC_CLEARSTAR_REACTOR_OPENEDEN_BOOSTED_ARK"
        );
        vm.label(
            address(usdcGauntletFrontierArk),
            "USDC_GAUNTLET_FRONTIER_ARK"
        );
        vm.label(address(usdcFluidERC4626Ark), "USDC_FLUID_ERC4626_ARK");
        vm.label(
            address(usdcEulerBaseERC4626Ark),
            "USDC_EULER_BASE_ERC4626_ARK"
        );
        vm.label(address(usdcBufferArk), "USDC_BUFFER_ARK");
    }

    function setupExternalContracts() internal {
        usdcTokenContract = IERC20(USDC_ADDRESS);
        aaveV3PoolContract = IPoolV3(AAVE_V3_POOL_ADDRESS);
        usdcCompoundCometContract = IComet(COMPOUND_USDC_COMET_ADDRESS);
        morphoContract = IMorpho(MORPHO_ADDRESS);
        fluidUsdcVault = IERC4626(FLUID_USDC_VAULT_ADDRESS);
        eulerBaseUsdcVault = IERC4626(EULER_BASE_USDC_VAULT_ADDRESS);
    }

    function setupArks() internal {
        ArkParams memory usdcArkParams = ArkParams({
            name: "USDC Ark",
            details: "USDC Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // USDC Arks - All available Morpho vaults + Compound, Aave, ERC4626
        usdcAaveArk = new AaveV3Ark(
            address(aaveV3PoolContract),
            AAVE_V3_REWARDS_CONTROLLER,
            usdcArkParams
        );
        usdcCompoundArk = new CompoundV3Ark(
            address(usdcCompoundCometContract),
            COMET_REWARDS,
            usdcArkParams
        );

        // All Morpho vaults
        usdcMoonwellFlagshipArk = new MorphoVaultArk(
            MOONWELL_FLAGSHIP_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcGauntletCoreArk = new MorphoVaultArk(
            GAUNTLET_USDC_CORE,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcGauntletPrimeArk = new MorphoVaultArk(
            GAUNTLET_USDC_PRIME,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcRe7Ark = new MorphoVaultArk(
            RE7_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcSteakhouseArk = new MorphoVaultArk(
            STEAKHOUSE_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcSparkArk = new MorphoVaultArk(
            SPARK_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcSeamlessArk = new MorphoVaultArk(
            SEAMLESS_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcSteakhouseHighYieldArk = new MorphoVaultArk(
            STEAKHOUSE_HIGH_YIELD_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcExtrafiXLendArk = new MorphoVaultArk(
            EXTRAFI_XLEND_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcUniversalArk = new MorphoVaultArk(
            UNIVERSAL_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcClearstarHighYieldArk = new MorphoVaultArk(
            CLEARSTAR_HIGH_YIELD_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcClearstarReactorOpenEdenBoostedArk = new MorphoVaultArk(
            CLEARSTAR_REACTOR_OPENEDEN_BOOSTED_USDC,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcGauntletFrontierArk = new MorphoVaultArk(
            GAUNTLET_USDC_FRONTIER,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );

        // ERC4626 vaults
        usdcFluidERC4626Ark = new ERC4626Ark(
            FLUID_USDC_VAULT_ADDRESS,
            usdcArkParams
        );
        usdcEulerBaseERC4626Ark = new ERC4626Ark(
            EULER_BASE_USDC_VAULT_ADDRESS,
            usdcArkParams
        );
    }

    function setupFleetCommander(uint256 initialTipRate) internal {
        // Setup USDC Fleet Commander
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, initialTipRate);
        usdcFleetCommander = fleetCommander;
        usdcBufferArk = bufferArk;
    }

    function addArksToFleetCommander() internal {
        // Add all USDC Arks to USDC Fleet Commander (17 total: 15 Morpho + 2 ERC4626 + Compound + Aave)
        usdcArks = new address[](17);
        usdcArks[0] = address(usdcCompoundArk);
        usdcArks[1] = address(usdcAaveArk);
        usdcArks[2] = address(usdcMoonwellFlagshipArk);
        usdcArks[3] = address(usdcGauntletCoreArk);
        usdcArks[4] = address(usdcGauntletPrimeArk);
        usdcArks[5] = address(usdcRe7Ark);
        usdcArks[6] = address(usdcSteakhouseArk);
        usdcArks[7] = address(usdcSparkArk);
        usdcArks[8] = address(usdcSeamlessArk);
        usdcArks[9] = address(usdcSteakhouseHighYieldArk);
        usdcArks[10] = address(usdcExtrafiXLendArk);
        usdcArks[11] = address(usdcUniversalArk);
        usdcArks[12] = address(usdcClearstarHighYieldArk);
        usdcArks[13] = address(usdcClearstarReactorOpenEdenBoostedArk);
        usdcArks[14] = address(usdcGauntletFrontierArk);
        usdcArks[15] = address(usdcFluidERC4626Ark);
        usdcArks[16] = address(usdcEulerBaseERC4626Ark);

        grantPermissions();

        // Add USDC Arks to USDC Fleet Commander
        vm.startPrank(governor);
        for (uint256 i = 0; i < usdcArks.length; i++) {
            usdcFleetCommander.addArk(usdcArks[i]);
        }
        vm.stopPrank();
    }

    function grantPermissions() internal {
        vm.startPrank(governor);
        // Grant permissions for USDC Fleet
        for (uint256 i = 0; i < usdcArks.length; i++) {
            accessManager.grantCommanderRole(
                address(usdcArks[i]),
                address(usdcFleetCommander)
            );
        }
        accessManager.grantCommanderRole(
            address(usdcBufferArk),
            address(usdcFleetCommander)
        );

        // Grant keeper role
        accessManager.grantKeeperRole(address(usdcFleetCommander), keeper);
        vm.stopPrank();
    }

    function logSetupInfo() internal view {
        console.log("USDC Fleet Commander:", address(usdcFleetCommander));
        console.log("Total USDC Arks:", usdcArks.length);

        // Log all Ark addresses
        console.log("USDC Compound Ark:", address(usdcCompoundArk));
        console.log("USDC Aave Ark:", address(usdcAaveArk));
        console.log(
            "USDC Moonwell Flagship Ark:",
            address(usdcMoonwellFlagshipArk)
        );
        console.log("USDC Gauntlet Core Ark:", address(usdcGauntletCoreArk));
        console.log("USDC Gauntlet Prime Ark:", address(usdcGauntletPrimeArk));
        console.log("USDC Re7 Ark:", address(usdcRe7Ark));
        console.log("USDC Steakhouse Ark:", address(usdcSteakhouseArk));
        console.log("USDC Spark Ark:", address(usdcSparkArk));
        console.log("USDC Seamless Ark:", address(usdcSeamlessArk));
        console.log(
            "USDC Steakhouse High Yield Ark:",
            address(usdcSteakhouseHighYieldArk)
        );
        console.log("USDC Extrafi XLend Ark:", address(usdcExtrafiXLendArk));
        console.log("USDC Universal Ark:", address(usdcUniversalArk));
        console.log(
            "USDC Clearstar High Yield Ark:",
            address(usdcClearstarHighYieldArk)
        );
        console.log(
            "USDC Clearstar Reactor OpenEden Boosted Ark:",
            address(usdcClearstarReactorOpenEdenBoostedArk)
        );
        console.log(
            "USDC Gauntlet Frontier Ark:",
            address(usdcGauntletFrontierArk)
        );
        console.log("USDC Fluid ERC4626 Ark:", address(usdcFluidERC4626Ark));
        console.log(
            "USDC Euler Base ERC4626 Ark:",
            address(usdcEulerBaseERC4626Ark)
        );
    }

    function test_DepositRebalanceWithdrawFromArks_USDCFleet_BaseFork() public {
        // Arrange
        uint256 usdcTotalDeposit = 17000 * 10 ** 6; // 17000 USDC (1000 per ark)
        uint256 usdcUserDeposit = usdcTotalDeposit / 17; // 1000 USDC per ark
        uint ARKS_TO_REBALANCE = 8;
        // Set deposit caps and minimum buffer balances
        setFleetParameters(usdcFleetCommander, usdcTotalDeposit, 0);

        // Mint tokens for user
        address usdcUser = address(0x1);
        deal(USDC_ADDRESS, usdcUser, usdcTotalDeposit);
        uint256 gasBeforeDeposit = gasleft();
        // User deposits
        depositForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );
        uint256 gasAfterDeposit = gasleft();

        console.log("Arks used for deposit            :", usdcArks.length);
        console.log(
            "Gas used for deposit             :",
            gasBeforeDeposit - gasAfterDeposit
        );

        uint256 gasBeforeRebalance = gasleft();
        // Rebalance funds to all Arks
        rebalanceToArks(usdcFleetCommander, usdcUserDeposit, ARKS_TO_REBALANCE);
        uint256 gasAfterRebalance = gasleft();
        console.log(
            "Gas used for rebalance to arks   :",
            gasBeforeRebalance - gasAfterRebalance
        );

        rebalanceFromArks(
            usdcFleetCommander,
            usdcUserDeposit,
            ARKS_TO_REBALANCE
        );
        uint256 gasAfterRebalanceFromArks = gasleft();
        console.log(
            "Gas used for rebalance from arks :",
            gasBeforeRebalance - gasAfterRebalanceFromArks
        );

        // Advance time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        // Check total assets and rates
        checkAssetsAndRates(usdcFleetCommander, "USDC", ARKS_TO_REBALANCE);

        // User withdraws
        withdrawForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );

        // Assert
        assertApproxEqAbs(
            usdcFleetCommander.totalAssets(),
            0,
            1000,
            "USDC Fleet: Total assets should be close to 0 after withdrawals"
        );
    }

    function test_DepositRebalanceWithMaxUintWithdraw_USDCFleet_BaseFork()
        public
    {
        // Arrange
        uint256 usdcTotalDeposit = 17000 * 10 ** 6; // 17000 USDC (1000 per ark)
        uint256 usdcUserDeposit = usdcTotalDeposit / 17; // 1000 USDC per ark

        // Set deposit caps and minimum buffer balances
        setFleetParameters(usdcFleetCommander, usdcTotalDeposit, 0);

        // Mint tokens for user
        address usdcUser = address(0x1);
        deal(USDC_ADDRESS, usdcUser, usdcTotalDeposit);

        // User deposits
        depositForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );

        // Rebalance funds to all Arks
        rebalanceToArks(
            usdcFleetCommander,
            usdcUserDeposit,
            usdcFleetCommander.getActiveArks().length
        );

        // Advance time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        // Check total assets and rates
        checkAssetsAndRates(
            usdcFleetCommander,
            "USDC",
            usdcFleetCommander.getActiveArks().length
        );

        // Second rebalance using max uint
        secondRebalanceWithMaxUint(usdcFleetCommander);

        // User withdraws
        withdrawForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );

        // Assert
        assertApproxEqAbs(
            usdcFleetCommander.totalAssets(),
            0,
            1000,
            "USDC Fleet: Total assets should be close to 0 after withdrawals"
        );
    }

    function setFleetParameters(
        IFleetCommander fleet,
        uint256 depositCap,
        uint256 minBufferBalance
    ) internal {
        FleetCommanderStorageWriter storageWriter = new FleetCommanderStorageWriter(
                address(fleet)
            );
        storageWriter.setDepositCap(depositCap);
        storageWriter.setminimumBufferBalance(minBufferBalance);
    }

    function depositForUser(
        IFleetCommander fleet,
        IERC20 token,
        address user,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        token.approve(address(fleet), amount);
        uint256 previewShares = fleet.previewDeposit(amount);
        uint256 gas = gasleft();
        uint256 depositedShares = fleet.deposit(amount, user);
        console.log("Gas used for deposit:", gas - gasleft());
        assertEq(
            previewShares,
            depositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleet.balanceOf(user),
            amount,
            "User balance should be equal to deposit"
        );
        vm.stopPrank();
    }

    function withdrawForUser(
        IFleetCommander fleet,
        IERC20 token,
        address user,
        uint256 expectedMinimumAmount
    ) internal {
        vm.startPrank(user);
        uint256 userShares = fleet.balanceOf(user);
        uint256 userAssets = fleet.previewRedeem(userShares);
        console.log("User shares:", userShares);
        console.log("User assets:", userAssets);
        uint256 gas = gasleft();
        fleet.withdraw(userAssets, user, user);
        console.log("Gas used for withdraw:", gas - gasleft());
        assertEq(fleet.balanceOf(user), 0, "User balance should be 0");
        assertGe(
            token.balanceOf(user),
            expectedMinimumAmount,
            "User should receive at least the expected minimum assets"
        );
        vm.stopPrank();
    }

    function rebalanceToArks(
        IFleetCommander fleet,
        uint256 amountPerArk,
        uint howManyArks
    ) internal {
        address[] memory arks = fleet.getActiveArks();
        FleetConfig memory config = fleet.getConfig();

        RebalanceData[] memory rebalanceData = new RebalanceData[](howManyArks);
        for (uint256 i = 0; i < howManyArks; i++) {
            rebalanceData[i] = RebalanceData({
                fromArk: address(config.bufferArk),
                toArk: arks[i],
                amount: amountPerArk,
                boardData: bytes(""),
                disembarkData: bytes("")
            });
        }

        // Advance time to move past cooldown window
        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleet.rebalance(rebalanceData);
    }
    function rebalanceFromArks(
        IFleetCommander fleet,
        uint256 amountPerArk,
        uint howManyArks
    ) internal {
        address[] memory arks = fleet.getActiveArks();
        FleetConfig memory config = fleet.getConfig();

        RebalanceData[] memory rebalanceData = new RebalanceData[](howManyArks);
        for (uint256 i = 0; i < howManyArks; i++) {
            rebalanceData[i] = RebalanceData({
                fromArk: arks[i],
                toArk: address(config.bufferArk),
                amount: amountPerArk,
                boardData: bytes(""),
                disembarkData: bytes("")
            });
        }

        // Advance time to move past cooldown window
        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleet.rebalance(rebalanceData);
    }
    function checkAssetsAndRates(
        IFleetCommander fleet,
        string memory fleetName,
        uint howManyArks
    ) internal view {
        address[] memory arks = fleet.getActiveArks();
        for (uint256 i = 0; i < howManyArks; i++) {
            IArk ark = IArk(arks[i]);
            console.log(
                string.concat(
                    fleetName,
                    " Ark ",
                    Strings.toString(i),
                    " assets:"
                ),
                ark.totalAssets()
            );

            assertTrue(
                ark.totalAssets() > 0,
                string.concat(
                    fleetName,
                    " Ark ",
                    Strings.toString(i),
                    " assets should have increased"
                )
            );
        }
    }

    function secondRebalanceWithMaxUint(IFleetCommander fleet) internal {
        address[] memory arks = fleet.getActiveArks();
        uint256[] memory arkRates = new uint256[](arks.length);
        uint256[] memory arkTotalAssets = new uint256[](arks.length);

        // Get rates and total assets for each ark
        for (uint256 i = 0; i < arks.length; i++) {
            arkRates[i] = i;
            arkTotalAssets[i] = IArk(arks[i]).totalAssets();
        }

        // Sort arks by index (descending order)
        for (uint256 i = 0; i < arks.length; i++) {
            for (uint256 j = i + 1; j < arks.length; j++) {
                if (arkRates[i] < arkRates[j]) {
                    (arks[i], arks[j]) = (arks[j], arks[i]);
                    (arkRates[i], arkRates[j]) = (arkRates[j], arkRates[i]);
                    (arkTotalAssets[i], arkTotalAssets[j]) = (
                        arkTotalAssets[j],
                        arkTotalAssets[i]
                    );
                }
            }
        }

        // Create rebalance data to move funds from lower index arks to higher index arks
        RebalanceData[] memory rebalanceData = new RebalanceData[](
            arks.length - 1
        );
        for (uint256 i = 1; i < arks.length; i++) {
            rebalanceData[i - 1] = RebalanceData({
                fromArk: arks[i],
                toArk: arks[0],
                amount: type(uint256).max,
                boardData: bytes(""),
                disembarkData: bytes("")
            });
        }

        vm.prank(keeper);
        fleet.rebalance(rebalanceData);

        // Verify that all funds are now in the first ark
        for (uint256 i = 1; i < arks.length; i++) {
            assertEq(
                IArk(arks[i]).totalAssets(),
                0,
                "Remaining arks should have 0 assets"
            );
        }
        assertApproxEqAbs(
            IArk(arks[0]).totalAssets(),
            fleet.totalAssets(),
            1000,
            "First ark should have all assets"
        );
    }
}
