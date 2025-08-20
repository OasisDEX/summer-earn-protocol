// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {IntentHandler} from "../src/contracts/IntentHandler.sol";
import {IntentBondFactory} from "../src/contracts/IntentBondFactory.sol";
import {Escrow} from "../src/contracts/Escrow.sol";
// Note: Using test oracle for now - replace with production oracle
import {MockIntentOracle} from "../src/mocks/MockIntentOracle.sol";
import {ArkParams} from "@summerfi/earn-protocol-contracts/types/ArkTypes.sol";
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
    address constant PROTOCOL_ACCESS_MANAGER =
        0x603821f86DeDC794A3225d62Afe1F175fe4AE861;
    address constant CONFIGURATION_MANAGER =
        0x17134eCce2bfDE9cfbd05D0faFfCB2e262E81eA1;
    address constant RAFT = 0xB5113dA0CaE7DDf19b8e25103B2F411148b8BAeb;
    address constant TIP_JAR = 0x637Fd808BD451fc61cB4cC04c7aBA048812012de;
    address constant HARBOR_COMMAND =
        0xE355F38F0144a9f07A1Dc8f95ED23658d96613AF;
    address constant FLEET_COMMANDER_REWARDS_MANAGER_FACTORY =
        0x90CaD67E09F79436F51E6a07B9267b002DfDFF03;

    // Tokens
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Aave V3 (Base)
    address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_V3_REWARDS =
        0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;

    // Fleet (provided by user)
    address constant USDC_FLEET = 0xf762b4E90b21be81E5673058ac01B83A5833A4d9;

    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Deployed contracts
    IntentBondFactory public intentBondFactory;
    IntentHandler public intentHandler;
    MockIntentOracle public intentOracle;

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

        // 1. Deploy Mock Intent Oracle (temporary for testing)
        console.log("2. Deploying MockIntentOracle...");
        intentOracle = new MockIntentOracle();
        console.log("   MockIntentOracle deployed at:", address(intentOracle));

        // 2. Deploy Intent Bond Factory
        console.log("1. Deploying IntentBondFactory...");
        intentBondFactory = new IntentBondFactory(
            SUMMER_TOKEN,
            PROTOCOL_ACCESS_MANAGER,
            address(intentOracle)
        );
        console.log(
            "   IntentBondFactory deployed at:",
            address(intentBondFactory)
        );

        // 3. Deploy Intent Handler
        console.log("3. Deploying IntentHandler...");
        intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(intentOracle),
            SUMMER_TOKEN,
            PROTOCOL_ACCESS_MANAGER
        );
        console.log("   IntentHandler deployed at:", address(intentHandler));

        // 6. Setup initial configuration
        console.log("6. Setting up initial configuration...");
        setupConfiguration();

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        logDeploymentSummary();

        console.log("");
        console.log("=== Next Steps ===");
        console.log(
            "1. Grant roles to appropriate addresses via ProtocolAccessManager"
        );
        console.log("2. Register fleet commander with the ark");
        console.log("3. Configure oracle with supported tokens");
        console.log(
            "4. Create solver bonds via IntentBondFactory.createBond()"
        );
        console.log(
            "5. Add solver escrows via IntentHandler.addSolverEscrow()"
        );
        console.log("");
        console.log("=== Security Notes ===");
        console.log(
            "- IntentHandler has handler role on factory (for bond slashing)"
        );
        console.log(
            "- Admin role remains with deployer for factory management"
        );
        console.log(
            "- Only authorized keepers can create intents and manage escrows"
        );
        console.log("- Solver bonds are managed individually per solver");
    }

    function setupConfiguration() internal {
        // Setup Intent Oracle with Summer Token support
        intentOracle.addSupportedToken(SUMMER_TOKEN);
        intentOracle.setPrice(SUMMER_TOKEN, 10000e18, 18); // $10000 per token, 18 decimals
        intentOracle.setPrice(USDC, 1e18, 6); // $1 per token, 6 decimals

        // Add solver escrow for the test solver
        intentHandler.addSolverEscrow(
            0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA,
            USDC
        );

        console.log("   - Oracle configured with Summer Token");
        console.log("   - Bond factory handler role granted to IntentHandler");
        console.log("   - Intent handler roles configured");
        console.log("   - Solver escrow added");
        console.log("   - Oracle configured with USDC");
    }

    function logDeploymentSummary() internal view {
        console.log("IntentBondFactory:    ", address(intentBondFactory));
        console.log("MockIntentOracle:     ", address(intentOracle));
        console.log("IntentHandler:        ", address(intentHandler));
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
