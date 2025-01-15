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
 * @title Lifecycle test suite for FleetCommander
 * @dev Test suite of full lifecycle tests for both USDC and DAI fleets
 */
contract LifecycleTest is Test, TestHelpers, FleetCommanderTestBase {
    // USDC Fleet Arks
    CompoundV3Ark public usdcCompoundArk;
    AaveV3Ark public usdcAaveArk;
    MorphoArk public usdcMorphoArk;
    MorphoVaultArk public usdcMetaMorphoArk;
    ERC4626Ark public usdcGearboxERC4626Ark;
    ERC4626Ark public usdcFluidERC4626Ark;
    BufferArk public usdcBufferArk;

    // DAI Fleet Arks
    AaveV3Ark public daiAaveArk;
    MorphoArk public daiMorphoArk;
    MorphoVaultArk public daiMetaMorphoArk;
    ERC4626Ark public sDAIArk;
    BufferArk public daiBufferArk;

    address[] public usdcArks;
    address[] public daiArks;

    // External contracts
    IComet public usdcCompoundCometContract;
    IPoolV3 public aaveV3PoolContract;
    IERC20 public usdcTokenContract;
    IERC20 public daiTokenContract;
    IMorpho public morphoContract;
    IMetaMorpho public usdcMetaMorphoContract;
    IMetaMorpho public daiMetaMorphoContract;
    IERC4626 public sDAIContract;
    IERC4626 public gearboxUsdcVault;
    IERC4626 public fluidUsdcVault;

    // Constants
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant AAVE_V3_POOL_ADDRESS =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant COMPOUND_USDC_COMET_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant COMET_REWARDS =
        0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
    address public constant AAVE_V3_REWARDS_CONTROLLER =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
    address public constant MORPHO_ADDRESS =
        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant USDC_METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    address public constant DAI_METAMORPHO_ADDRESS =
        0x500331c9fF24D9d11aee6B07734Aa72343EA74a5;
    address public constant SDAI_ADDRESS =
        0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant POT_ADDRESS =
        0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;
    address public constant GEARBOX_USDC_VAULT_ADDRESS =
        0xda00000035fef4082F78dEF6A8903bee419FbF8E;
    address public constant FLUID_USDC_VAULT_ADDRESS =
        0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address public constant MORPHO_URD_FACTORY =
        0x9baA51245CDD28D8D74Afe8B3959b616E9ee7c8D;

    Id public constant USDC_MORPHO_MARKET_ID =
        Id.wrap(
            0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49
        );
    Id public constant DAI_MORPHO_MARKET_ID =
        Id.wrap(
            0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f
        );
    uint256 constant FORK_BLOCK = 20376149;

    // Fleet Commanders
    IFleetCommander public usdcFleetCommander;
    IFleetCommander public daiFleetCommander;

    function setUp() public {
        console.log("Setting up LifecycleTest");

        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        uint256 initialTipRate = 0;
        setupExternalContracts();
        setupFleetCommanders(initialTipRate);
        setupArks();
        addArksToFleetCommanders();

        logSetupInfo();
        setupLabels();
    }

    function setupLabels() internal {
        vm.label(USDC_ADDRESS, "USDC");
        vm.label(DAI_ADDRESS, "DAI");
        vm.label(AAVE_V3_POOL_ADDRESS, "AAVE_V3_POOL");
        vm.label(COMPOUND_USDC_COMET_ADDRESS, "COMPOUND_USDC_COMET");
        vm.label(COMET_REWARDS, "COMET_REWARDS");
        vm.label(AAVE_V3_REWARDS_CONTROLLER, "AAVE_V3_REWARDS_CONTROLLER");
        vm.label(MORPHO_ADDRESS, "MORPHO");
        vm.label(USDC_METAMORPHO_ADDRESS, "USDC_METAMORPHO");
        vm.label(DAI_METAMORPHO_ADDRESS, "DAI_METAMORPHO");
        vm.label(SDAI_ADDRESS, "SDAI");
        vm.label(POT_ADDRESS, "POT");
        vm.label(GEARBOX_USDC_VAULT_ADDRESS, "USDC_VAULT");
        vm.label(FLUID_USDC_VAULT_ADDRESS, "FLUID_USDC_VAULT");
        vm.label(address(usdcCompoundArk), "USDC_COMPOUND_ARK");
        vm.label(address(usdcAaveArk), "USDC_AAVE_ARK");
        vm.label(address(usdcMorphoArk), "USDC_MORPHO_ARK");
        vm.label(address(usdcMetaMorphoArk), "USDC_METAMORPHO_ARK");
        vm.label(address(usdcGearboxERC4626Ark), "USDC_ERC4626_ARK");
        vm.label(address(usdcBufferArk), "USDC_BUFFER_ARK");
        vm.label(address(daiAaveArk), "DAI_AAVE_ARK");
        vm.label(address(daiMorphoArk), "DAI_MORPHO_ARK");
        vm.label(address(daiMetaMorphoArk), "DAI_METAMORPHO_ARK");
        vm.label(address(sDAIArk), "SDAI_ARK");
        vm.label(address(daiBufferArk), "DAI_BUFFER_ARK");
    }

    function setupExternalContracts() internal {
        usdcTokenContract = IERC20(USDC_ADDRESS);
        daiTokenContract = IERC20(DAI_ADDRESS);
        aaveV3PoolContract = IPoolV3(AAVE_V3_POOL_ADDRESS);
        usdcCompoundCometContract = IComet(COMPOUND_USDC_COMET_ADDRESS);
        morphoContract = IMorpho(MORPHO_ADDRESS);
        usdcMetaMorphoContract = IMetaMorpho(USDC_METAMORPHO_ADDRESS);
        daiMetaMorphoContract = IMetaMorpho(DAI_METAMORPHO_ADDRESS);
        sDAIContract = IERC4626(SDAI_ADDRESS);
        gearboxUsdcVault = IERC4626(GEARBOX_USDC_VAULT_ADDRESS);
        fluidUsdcVault = IERC4626(FLUID_USDC_VAULT_ADDRESS);
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

        ArkParams memory daiArkParams = ArkParams({
            name: "DAI Ark",
            details: "DAI Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: DAI_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // USDC Arks
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
        usdcMorphoArk = new MorphoArk(
            MORPHO_ADDRESS,
            USDC_MORPHO_MARKET_ID,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcMetaMorphoArk = new MorphoVaultArk(
            USDC_METAMORPHO_ADDRESS,
            MORPHO_URD_FACTORY,
            usdcArkParams
        );
        usdcGearboxERC4626Ark = new ERC4626Ark(
            GEARBOX_USDC_VAULT_ADDRESS,
            usdcArkParams
        );
        usdcFluidERC4626Ark = new ERC4626Ark(
            FLUID_USDC_VAULT_ADDRESS,
            usdcArkParams
        );
        // DAI Arks
        daiAaveArk = new AaveV3Ark(
            address(aaveV3PoolContract),
            AAVE_V3_REWARDS_CONTROLLER,
            daiArkParams
        );
        daiMorphoArk = new MorphoArk(
            MORPHO_ADDRESS,
            DAI_MORPHO_MARKET_ID,
            MORPHO_URD_FACTORY,
            daiArkParams
        );
        daiMetaMorphoArk = new MorphoVaultArk(
            DAI_METAMORPHO_ADDRESS,
            MORPHO_URD_FACTORY,
            daiArkParams
        );
        sDAIArk = new ERC4626Ark(SDAI_ADDRESS, daiArkParams);
    }

    function setupFleetCommanders(uint256 initialTipRate) internal {
        // Setup USDC Fleet Commander
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, initialTipRate);
        usdcFleetCommander = fleetCommander;
        usdcBufferArk = bufferArk;

        // Setup DAI Fleet Commander
        initializeFleetCommanderWithoutArks(DAI_ADDRESS, initialTipRate);
        daiFleetCommander = fleetCommander;
        daiBufferArk = bufferArk;
    }

    function addArksToFleetCommanders() internal {
        // Add USDC Arks to USDC Fleet Commander
        usdcArks = new address[](6);
        usdcArks[0] = address(usdcCompoundArk);
        usdcArks[1] = address(usdcAaveArk);
        usdcArks[2] = address(usdcMorphoArk);
        usdcArks[3] = address(usdcMetaMorphoArk);
        usdcArks[4] = address(usdcGearboxERC4626Ark);
        usdcArks[5] = address(usdcFluidERC4626Ark);

        // Add DAI Arks to DAI Fleet Commander
        daiArks = new address[](4);
        daiArks[0] = address(daiAaveArk);
        daiArks[1] = address(daiMorphoArk);
        daiArks[2] = address(daiMetaMorphoArk);
        daiArks[3] = address(sDAIArk);

        grantPermissions();

        // Add USDC Arks to USDC Fleet Commander
        vm.startPrank(governor);
        for (uint256 i = 0; i < usdcArks.length; i++) {
            usdcFleetCommander.addArk(usdcArks[i]);
        }

        for (uint256 i = 0; i < daiArks.length; i++) {
            daiFleetCommander.addArk(daiArks[i]);
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
        for (uint256 i = 0; i < daiArks.length; i++) {
            accessManager.grantCommanderRole(
                address(daiArks[i]),
                address(daiFleetCommander)
            );
        }
        accessManager.grantCommanderRole(
            address(usdcBufferArk),
            address(usdcFleetCommander)
        );
        accessManager.grantCommanderRole(
            address(daiBufferArk),
            address(daiFleetCommander)
        );

        // Grant keeper role
        accessManager.grantKeeperRole(address(usdcFleetCommander), keeper);
        accessManager.grantKeeperRole(address(daiFleetCommander), keeper);
        vm.stopPrank();
    }

    function logSetupInfo() internal view {
        console.log("USDC Fleet Commander:", address(usdcFleetCommander));
        console.log("DAI Fleet Commander:", address(daiFleetCommander));
        // Log USDC Ark addresses
        console.log("USDC Aave Ark:", address(usdcAaveArk));
        console.log("USDC Compound Ark:", address(usdcCompoundArk));
        console.log("USDC Morpho Ark:", address(usdcMorphoArk));
        console.log("USDC MetaMorpho Ark:", address(usdcMetaMorphoArk));
        console.log(
            "USDC Gearbox ERC4626 Ark:",
            address(usdcGearboxERC4626Ark)
        );
        console.log("USDC Fluid ERC4626 Ark:", address(usdcFluidERC4626Ark));
        // Log DAI Ark addresses
        console.log("DAI Aave Ark:", address(daiAaveArk));
        console.log("DAI Morpho Ark:", address(daiMorphoArk));
        console.log("DAI MetaMorpho Ark:", address(daiMetaMorphoArk));
        console.log("SDAI Ark:", address(sDAIArk));
    }

    function test_DepositRebalanceWithdrawFromArks_BothFleets_Fork() public {
        // Arrange
        uint256 usdcTotalDeposit = 6000 * 10 ** 6; // 6000 USDC
        uint256 daiTotalDeposit = 4000 * 10 ** 18; // 4000 DAI
        uint256 usdcUserDeposit = usdcTotalDeposit / 6; // 1000 USDC per ark
        uint256 daiUserDeposit = daiTotalDeposit / 4; // 1000 DAI per ark

        // Set deposit caps and minimum buffer balances
        setFleetParameters(usdcFleetCommander, usdcTotalDeposit, 0);
        setFleetParameters(daiFleetCommander, daiTotalDeposit, 0);

        // Mint tokens for users
        address usdcUser = address(0x1);
        address daiUser = address(0x2);
        deal(USDC_ADDRESS, usdcUser, usdcTotalDeposit);
        deal(DAI_ADDRESS, daiUser, daiTotalDeposit);

        // Users deposit
        depositForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );
        depositForUser(
            daiFleetCommander,
            daiTokenContract,
            daiUser,
            daiTotalDeposit
        );

        // Rebalance funds to all Arks for both fleets
        rebalanceFleet(usdcFleetCommander, usdcUserDeposit);
        rebalanceFleet(daiFleetCommander, daiUserDeposit);

        // Advance time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        // Accrue interest for Morpho markets
        accrueInterestForMorphoMarkets();

        // Check total assets and rates for both fleets
        checkAssetsAndRates(usdcFleetCommander, "USDC");
        checkAssetsAndRates(daiFleetCommander, "DAI");

        // Users withdraw
        withdrawForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );
        withdrawForUser(
            daiFleetCommander,
            daiTokenContract,
            daiUser,
            daiTotalDeposit
        );

        // Assert
        assertApproxEqAbs(
            usdcFleetCommander.totalAssets(),
            0,
            1000,
            "USDC Fleet: Total assets should be close to 0 after withdrawals"
        );
        assertApproxEqAbs(
            daiFleetCommander.totalAssets(),
            0,
            1e15, // Allow for slightly larger rounding errors due to DAI's 18 decimals
            "DAI Fleet: Total assets should be close to 0 after withdrawals"
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

    function rebalanceFleet(
        IFleetCommander fleet,
        uint256 amountPerArk
    ) internal {
        address[] memory arks = fleet.getActiveArks();
        FleetConfig memory config = fleet.getConfig();

        RebalanceData[] memory rebalanceData = new RebalanceData[](arks.length);
        for (uint256 i = 0; i < arks.length; i++) {
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

    function accrueInterestForMorphoMarkets() internal {
        morphoContract.accrueInterest(
            morphoContract.idToMarketParams(USDC_MORPHO_MARKET_ID)
        );
        morphoContract.accrueInterest(
            morphoContract.idToMarketParams(DAI_MORPHO_MARKET_ID)
        );
    }

    function checkAssetsAndRates(
        IFleetCommander fleet,
        string memory fleetName
    ) internal view {
        address[] memory arks = fleet.getActiveArks();
        for (uint256 i = 0; i < arks.length; i++) {
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

    function test_DepositRebalanceWithMaxUintWithdraw_BothFleets_Fork() public {
        // Arrange
        uint256 usdcTotalDeposit = 6000 * 10 ** 6; // 6000 USDC
        uint256 daiTotalDeposit = 4000 * 10 ** 18; // 4000 DAI
        uint256 usdcUserDeposit = usdcTotalDeposit / 6; // 1000 USDC per ark
        uint256 daiUserDeposit = daiTotalDeposit / 4; // 1000 DAI per ark

        // Set deposit caps and minimum buffer balances
        setFleetParameters(usdcFleetCommander, usdcTotalDeposit, 0);
        setFleetParameters(daiFleetCommander, daiTotalDeposit, 0);

        // Mint tokens for users
        address usdcUser = address(0x1);
        address daiUser = address(0x2);
        deal(USDC_ADDRESS, usdcUser, usdcTotalDeposit);
        deal(DAI_ADDRESS, daiUser, daiTotalDeposit);

        // Users deposit
        depositForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );
        depositForUser(
            daiFleetCommander,
            daiTokenContract,
            daiUser,
            daiTotalDeposit
        );

        // Rebalance funds to all Arks for both fleets
        rebalanceFleet(usdcFleetCommander, usdcUserDeposit);
        rebalanceFleet(daiFleetCommander, daiUserDeposit);

        // Advance time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        // Accrue interest for Morpho markets
        accrueInterestForMorphoMarkets();

        // Check total assets and rates for both fleets
        checkAssetsAndRates(usdcFleetCommander, "USDC");
        checkAssetsAndRates(daiFleetCommander, "DAI");

        // Second rebalance using max uint for both fleets
        secondRebalanceWithMaxUint(usdcFleetCommander);
        secondRebalanceWithMaxUint(daiFleetCommander);

        // Users withdraw
        withdrawForUser(
            usdcFleetCommander,
            usdcTokenContract,
            usdcUser,
            usdcTotalDeposit
        );
        withdrawForUser(
            daiFleetCommander,
            daiTokenContract,
            daiUser,
            daiTotalDeposit
        );

        // Assert
        assertApproxEqAbs(
            usdcFleetCommander.totalAssets(),
            0,
            1000,
            "USDC Fleet: Total assets should be close to 0 after withdrawals"
        );
        assertApproxEqAbs(
            daiFleetCommander.totalAssets(),
            0,
            1e15,
            "DAI Fleet: Total assets should be close to 0 after withdrawals"
        );
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
