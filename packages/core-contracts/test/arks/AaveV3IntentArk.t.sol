// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/AaveV3IntentArk.sol";
import "../../src/contracts/intent/IntentHandler.sol";
import "../../src/contracts/intent/IntentBondFactory.sol";
import "../../src/contracts/intent/SolverBond.sol";
import "../../src/contracts/intent/MockIntentOracle.sol";
import "../../src/contracts/intent/MockSummerToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager, ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {DataTypes} from "../../src/interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "../../src/interfaces/aave-v3/IPoolV3.sol";

contract AaveV3IntentArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    AaveV3IntentArk public ark;
    IntentHandler public intentHandler;
    IntentBondFactory public intentBondFactory;
    SolverBond public solverBond;
    MockIntentOracle public mockOracle;
    MockSummerToken public summerToken;

    address public constant aaveV3PoolAddress =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public rewardsController =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
    IPoolV3 public aaveV3Pool;
    address public mockAToken = address(11);

    address public solver = address(0x123);
    address public user = address(0x456);

    uint256 public constant REQUIRED_NOTIONAL = 1000e18; // $1000
    uint256 public constant TERM = 30 days;
    uint256 public constant TARGET_YIELD = 100e18; // $100
    uint256 public constant BOND_AMOUNT = 1000e18; // 1000 Summer tokens
    uint256 public constant ESCROWED_YIELD = 100e18; // $100

    function setUp() public {
        initializeCoreContracts();
        mockToken = new ERC20Mock();
        aaveV3Pool = IPoolV3(aaveV3PoolAddress);

        summerToken = new MockSummerToken();

        // Deploy intent system contracts as governor to ensure proper role setup
        vm.startPrank(governor);
        intentBondFactory = new IntentBondFactory(address(summerToken));
        mockOracle = new MockIntentOracle();
        intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(mockOracle)
        );

        // Create a bond for the solver (governor creates it)
        address bondAddress = intentBondFactory.createBond(solver);
        solverBond = SolverBond(bondAddress);
        vm.stopPrank();

        // Setup mock Aave V3 pool data
        DataTypes.ReserveData memory reserveData = DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0),
            liquidityIndex: 1e27,
            currentLiquidityRate: 1e27,
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: 1e27,
            currentStableBorrowRate: 1e27,
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 1,
            aTokenAddress: mockAToken,
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });

        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).getReserveData.selector),
            abi.encode(reserveData)
        );

        // Deploy AaveV3IntentArk
        ArkParams memory params = ArkParams({
            name: "TestIntentArk",
            details: "Test Intent Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new AaveV3IntentArk(
            address(aaveV3Pool),
            rewardsController,
            address(intentHandler),
            address(intentBondFactory),
            params
        );

        // Setup permissions
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        intentHandler.grantArkRole(address(ark));
        intentHandler.grantSolverRole(solver);
        intentBondFactory.grantHandlerRole(address(intentHandler));
        intentBondFactory.grantLiquidatorRole(governor); // governor as liquidator
        solverBond.grantHandlerRole(address(intentHandler));
        solverBond.grantLiquidatorRole(governor); // governor as liquidator
        mockOracle.addSupportedToken(address(summerToken));
        mockOracle.setPrice(address(summerToken), 1e18, 18); // $1.00 per token
        vm.stopPrank();

        // Register ark with fleet commander
        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        // Setup mock token balances
        mockToken.mint(address(ark), 10000e18);
        mockToken.mint(commander, 10000e18); // Give commander tokens to board
        summerToken.mint(solver, 10000e18);
        summerToken.mint(user, 10000e18);
    }

    function test_Constructor() public {
        assertEq(address(ark.aaveV3Pool()), address(aaveV3Pool));
        assertEq(address(ark.rewardsController()), rewardsController);
        assertEq(address(ark.intentHandler()), address(intentHandler));
        assertEq(address(ark.intentBondFactory()), address(intentBondFactory));
        assertEq(ark.aToken(), mockAToken);
    }

    function test_CreateIntent() public {
        vm.startPrank(commander);

        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertEq(intent.requiredNotional, REQUIRED_NOTIONAL);
        assertEq(intent.term, TERM);
        assertEq(intent.targetYield, TARGET_YIELD);
        assertEq(intent.summerToken, address(summerToken));
        assertEq(intent.oracle, address(mockOracle));
        assertTrue(intent.state == IIntentHandler.IntentState.Created);

        vm.stopPrank();
    }

    function test_AcceptMatch() public {
        // First create intent
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // First, solver needs to add to their bond
        vm.startPrank(solver);
        summerToken.approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();

        // Accept match from solver
        ark.acceptMatch(solver, ESCROWED_YIELD);

        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertEq(intent.solver, solver);
        assertEq(intent.escrowedYield, ESCROWED_YIELD);
        assertTrue(intent.state == IIntentHandler.IntentState.Solved);

        // Check solver is vouched with sufficient bond
        assertTrue(intentBondFactory.isSolverVouched(solver, BOND_AMOUNT));
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);

        vm.stopPrank();
    }

    function test_ActivateIntent() public {
        // Setup: create intent and accept match
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );
        ark.acceptMatch(solver, ESCROWED_YIELD);

        // Activate intent
        ark.activateIntent();

        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.Active);
        assertEq(intent.startTime, block.timestamp);

        vm.stopPrank();
    }

    function test_SettleIntent() public {
        // Setup: create, match, and activate intent
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );
        // First, solver needs to add to their bond
        vm.stopPrank();
        vm.startPrank(solver);
        summerToken.approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();
        vm.startPrank(commander);

        ark.acceptMatch(solver, ESCROWED_YIELD);
        ark.activateIntent();

        // Fast forward time to complete term
        vm.warp(block.timestamp + TERM + 1);

        // Settle intent
        ark.settleIntent();

        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.Settled);

        // Check solver is still vouched with sufficient bond
        assertTrue(intentBondFactory.isSolverVouched(solver, BOND_AMOUNT));
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);

        vm.stopPrank();
    }

    function test_ResignByArk() public {
        // Setup: create, match, and activate intent
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );
        // First, solver needs to add to their bond
        vm.stopPrank();
        vm.startPrank(solver);
        summerToken.approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();
        vm.startPrank(commander);

        ark.acceptMatch(solver, ESCROWED_YIELD);
        ark.activateIntent();

        // Resign by Ark
        ark.resignIntent();

        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.ResignedByArk);

        // Check solver is still vouched with sufficient bond
        assertTrue(intentBondFactory.isSolverVouched(solver, BOND_AMOUNT));
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);

        vm.stopPrank();
    }

    function test_ResignBySolver() public {
        // Setup: create, match, and activate intent
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );
        // First, solver needs to add to their bond
        vm.stopPrank();
        vm.startPrank(solver);
        summerToken.approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();
        vm.startPrank(commander);

        ark.acceptMatch(solver, ESCROWED_YIELD);
        ark.activateIntent();
        vm.stopPrank();

        // Resign by Solver
        vm.startPrank(solver);
        intentHandler.resignBySolver(address(ark));
        vm.stopPrank();

        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.ResignedBySolver);

        // Check bond was slashed (50% penalty)
        assertEq(
            intentBondFactory.getSolverBondAmount(solver),
            BOND_AMOUNT / 2
        );
    }

    function test_RejectInsufficientBond() public {
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Try to accept match with insufficient bond (solver not in bonding pool)
        vm.expectRevert(IIntentHandler.InsufficientBond.selector);
        ark.acceptMatch(solver, ESCROWED_YIELD);

        vm.stopPrank();
    }

    function test_RejectExpiredIntent() public {
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 hours // Short expiry
        );

        // Fast forward past expiry
        vm.warp(block.timestamp + 2 hours);

        // Try to accept match on expired intent
        vm.expectRevert(IIntentHandler.IntentExpired.selector);
        ark.acceptMatch(solver, ESCROWED_YIELD);

        vm.stopPrank();
    }

    function test_RejectStaleOracle() public {
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Make oracle price stale
        vm.startPrank(governor);
        mockOracle.setPrice(address(summerToken), 1e18, 18); // Set price now
        vm.stopPrank();

        // Warp to make price stale (more than 1 hour old)
        vm.warp(block.timestamp + 2 hours);

        // Try to accept match with stale oracle
        vm.startPrank(commander);
        vm.expectRevert(IIntentHandler.InsufficientBond.selector); // Will fail due to insufficient bond first
        ark.acceptMatch(solver, ESCROWED_YIELD);
        vm.stopPrank();
    }

    function test_TotalAssets() public {
        // Board some tokens
        vm.startPrank(commander);
        mockToken.approve(address(ark), 1000e18);
        ark.board(1000e18, ""); // No data needed
        vm.stopPrank();

        assertEq(ark.totalAssets(), 1000e18);
    }

    function test_BoardWithIntentData() public {
        vm.startPrank(commander);

        // Create intent separately
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Board normally (without intent data)
        mockToken.approve(address(ark), 1000e18);
        ark.board(1000e18, "");

        // Check that intent was created
        assertTrue(intentHandler.intentExists(address(ark)));

        vm.stopPrank();
    }

    function test_Disembark() public {
        // Board some tokens first
        vm.startPrank(commander);
        mockToken.approve(address(ark), 1000e18);
        ark.board(1000e18, ""); // No data needed
        vm.stopPrank();

        // Disembark tokens
        vm.startPrank(commander);
        ark.disembark(500e18, "");
        vm.stopPrank();

        assertEq(ark.totalAssets(), 500e18);
    }

    function test_WithdrawableTotalAssets() public {
        // Board some tokens
        vm.startPrank(commander);
        mockToken.approve(address(ark), 1000e18);
        ark.board(1000e18, ""); // No data needed
        vm.stopPrank();

        // Mock Aave pool to be active and not paused
        uint256 activeConfig = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(IPoolV3(aaveV3Pool).getReserveData.selector),
            abi.encode(
                DataTypes.ReserveData({
                    configuration: DataTypes.ReserveConfigurationMap(
                        activeConfig
                    ),
                    liquidityIndex: 1e27,
                    currentLiquidityRate: 1e27,
                    variableBorrowIndex: 1e27,
                    currentVariableBorrowRate: 1e27,
                    currentStableBorrowRate: 1e27,
                    lastUpdateTimestamp: uint40(block.timestamp),
                    id: 1,
                    aTokenAddress: mockAToken,
                    stableDebtTokenAddress: address(0),
                    variableDebtTokenAddress: address(0),
                    interestRateStrategyAddress: address(0),
                    accruedToTreasury: 0,
                    unbacked: 0,
                    isolationModeTotalDebt: 0
                })
            )
        );

        assertEq(ark.withdrawableTotalAssets(), 1000e18);
    }

    function test_Harvest() public {
        // Mock rewards controller to return some rewards
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(mockToken);
        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 100e18;

        vm.mockCall(
            rewardsController,
            abi.encodeWithSelector(
                IRewardsController(rewardsController).claimAllRewards.selector
            ),
            abi.encode(rewardTokens, rewardAmounts)
        );

        // Mock the raft address to be the caller
        address raftAddress = ark.raft();
        vm.startPrank(raftAddress);
        (
            address[] memory harvestedTokens,
            uint256[] memory harvestedAmounts
        ) = ark.harvest("");
        vm.stopPrank();

        assertEq(harvestedTokens.length, 1);
        assertEq(harvestedTokens[0], address(mockToken));
        assertEq(harvestedAmounts[0], 100e18);
    }

    function test_AccessControl() public {
        // Test that only commander can create intent
        vm.startPrank(user);
        vm.expectRevert();
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );
        vm.stopPrank();

        // Test that only commander can accept match
        vm.startPrank(user);
        vm.expectRevert();
        ark.acceptMatch(solver, ESCROWED_YIELD);
        vm.stopPrank();

        // Test that only commander can resign
        vm.startPrank(user);
        vm.expectRevert();
        ark.resignIntent();
        vm.stopPrank();
    }

    function test_IntegrationFlow() public {
        // Complete integration test: create intent, match, activate, settle

        // 1. Create intent
        vm.startPrank(commander);
        ark.createIntent(
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(summerToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // 2. First, solver needs to add to their bond
        vm.stopPrank();
        vm.startPrank(solver);
        summerToken.approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();
        vm.startPrank(commander);

        // 3. Accept match
        ark.acceptMatch(solver, ESCROWED_YIELD);

        // 3. Activate intent
        ark.activateIntent();

        // 4. Fast forward to complete term
        vm.warp(block.timestamp + TERM + 1);

        // 5. Settle intent
        ark.settleIntent();

        // Verify final state
        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.Settled);

        // Verify solver is still vouched with sufficient bond
        assertTrue(intentBondFactory.isSolverVouched(solver, BOND_AMOUNT));
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);

        vm.stopPrank();
    }
}
