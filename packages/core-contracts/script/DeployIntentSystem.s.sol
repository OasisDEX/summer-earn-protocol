// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {GenericIntentArk} from "../src/contracts/arks/GenericIntentArk.sol";
import {IntentHandler} from "../src/contracts/intent/IntentHandler.sol";
import {IntentBondFactory} from "../src/contracts/intent/IntentBondFactory.sol";
import {AaveV3Escrow} from "../src/contracts/adapters/AaveV3Escrow.sol";
// Note: Using test oracle for now - replace with production oracle
import {MockIntentOracle} from "../src/contracts/intent/MockIntentOracle.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deploy Intent System Script
 * @notice Deploys the complete intent system on Base using production addresses
 * @dev Uses existing Summer infrastructure and creates new intent-specific contracts
 */
contract DeployIntentSystem is Script {
    /*//////////////////////////////////////////////////////////////
                                BASE ADDRESSES
    //////////////////////////////////////////////////////////////*/
    
    // Summer Infrastructure (from config)
    address constant SUMMER_TOKEN = 0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32;
    address constant PROTOCOL_ACCESS_MANAGER = 0x603821f86DeDC794A3225d62Afe1F175fe4AE861;
    address constant CONFIGURATION_MANAGER = 0x17134eCce2bfDE9cfbd05D0faFfCB2e262E81eA1;
    address constant RAFT = 0xB5113dA0CaE7DDf19b8e25103B2F411148b8BAeb;
    address constant TIP_JAR = 0x637Fd808BD451fc61cB4cC04c7aBA048812012de;
    address constant HARBOR_COMMAND = 0xE355F38F0144a9f07A1Dc8f95ED23658d96613AF;
    address constant FLEET_COMMANDER_REWARDS_MANAGER_FACTORY = 0x90CaD67E09F79436F51E6a07B9267b002DfDFF03;
    
    // Tokens
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // Aave V3 (Base)
    address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_V3_REWARDS = 0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;
    
    // Fleet (provided by user)
    address constant USDC_FLEET = 0xf762b4E90b21be81E5673058ac01B83A5833A4d9;
    
    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    // Deployed contracts
    IntentBondFactory public intentBondFactory;
    IntentHandler public intentHandler;
    MockIntentOracle public intentOracle;
    GenericIntentArk public genericIntentArk;
    AaveV3Escrow public aaveV3Escrow;
    
    // Deployment addresses for logging
    address public deployer;
    
    function run() external {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Intent System Deployment on Base ===");
        console.log("Deployer:", deployer);
        console.log("USDC Fleet:", USDC_FLEET);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy Intent Bond Factory
        console.log("1. Deploying IntentBondFactory...");
        intentBondFactory = new IntentBondFactory(SUMMER_TOKEN);
        console.log("   IntentBondFactory deployed at:", address(intentBondFactory));
        
        // 2. Deploy Mock Intent Oracle (temporary for testing)
        console.log("2. Deploying MockIntentOracle...");
        intentOracle = new MockIntentOracle();
        console.log("   MockIntentOracle deployed at:", address(intentOracle));
        
        // 3. Deploy Intent Handler
        console.log("3. Deploying IntentHandler...");
        intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(intentOracle),
            SUMMER_TOKEN
        );
        console.log("   IntentHandler deployed at:", address(intentHandler));
        
        // 4. Deploy Generic Intent Ark
        console.log("4. Deploying GenericIntentArk...");
        ArkParams memory arkParams = ArkParams({
            name: "USDC Intent Ark",
            details: "Generic Intent Ark for USDC yield generation on Base",
            accessManager: PROTOCOL_ACCESS_MANAGER,
            configurationManager: CONFIGURATION_MANAGER,
            asset: USDC,
            depositCap: type(uint256).max, // No deposit cap initially
            maxRebalanceOutflow: type(uint256).max, // No rebalance limits initially
            maxRebalanceInflow: type(uint256).max, // No rebalance limits initially
            requiresKeeperData: false, // No keeper data required initially
            maxDepositPercentageOfTVL: Percentage.wrap(1e18) // 100%
        });
        
        genericIntentArk = new GenericIntentArk(
            arkParams,
            address(intentHandler),
            address(intentBondFactory)
        );
        console.log("   GenericIntentArk deployed at:", address(genericIntentArk));
        
        // 5. Deploy Aave V3 Escrow Adapter
        console.log("5. Deploying AaveV3Escrow...");
        aaveV3Escrow = new AaveV3Escrow(
            PROTOCOL_ACCESS_MANAGER,
            AAVE_V3_POOL,
            AAVE_V3_REWARDS,
            address(genericIntentArk)
        );
        console.log("   AaveV3Escrow deployed at:", address(aaveV3Escrow));
        
        // 6. Setup initial configuration
        console.log("6. Setting up initial configuration...");
        setupConfiguration();
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Deployment Summary ===");
        logDeploymentSummary();
        
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Grant roles to appropriate addresses via ProtocolAccessManager");
        console.log("2. Register fleet commander with the ark");
        console.log("3. Add solver adapters via IntentHandler.addSolverAdapter()");
        console.log("4. Configure oracle with supported tokens");
        console.log("5. Create solver bonds via IntentBondFactory.createBond()");
    }
    
    function setupConfiguration() internal {
        // Setup Intent Oracle with Summer Token support
        intentOracle.addSupportedToken(SUMMER_TOKEN);
        intentOracle.setPrice(SUMMER_TOKEN, 10000e18, 18); // $10000 per token, 18 decimals
        intentOracle.setPrice(USDC, 1e18, 6); // $1 per token, 6 decimals
        // Setup Intent Bond Factory roles
        intentBondFactory.grantHandlerRole(address(intentHandler));
        
        // Grant IntentHandler admin role on factory for bond slashing
        intentBondFactory.grantRole(
            intentBondFactory.DEFAULT_ADMIN_ROLE(),
            address(intentHandler)
        );
        
        // Grant Ark role to the GenericIntentArk
        intentHandler.grantArkRole(address(genericIntentArk));
        intentHandler.grantSolverRole(0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA);
        intentHandler.addSolverAdapter(0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA, address(aaveV3Escrow));
        
        console.log("   - Oracle configured with Summer Token");
        console.log("   - Bond factory roles configured");
        console.log("   - Intent handler roles configured");
        console.log("   - Ark role granted");
        console.log("   - Solver adapter added");
        console.log("   - Oracle configured with USDC");
    }
    
    function logDeploymentSummary() internal view {
        console.log("IntentBondFactory:    ", address(intentBondFactory));
        console.log("MockIntentOracle:     ", address(intentOracle));
        console.log("IntentHandler:        ", address(intentHandler));
        console.log("GenericIntentArk:     ", address(genericIntentArk));
        console.log("AaveV3Escrow:         ", address(aaveV3Escrow));
        console.log("");
        console.log("=== Configuration ===");
        console.log("Asset (USDC):         ", USDC);
        console.log("Summer Token:         ", SUMMER_TOKEN);
        console.log("Access Manager:       ", PROTOCOL_ACCESS_MANAGER);
        console.log("Config Manager:       ", CONFIGURATION_MANAGER);
        console.log("Fleet Address:        ", USDC_FLEET);
        console.log("Aave V3 Pool:         ", AAVE_V3_POOL);
        console.log("Aave V3 Rewards:      ", AAVE_V3_REWARDS);
    }
}
