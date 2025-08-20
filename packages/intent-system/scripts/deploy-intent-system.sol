// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/contracts/intent/IntentHandler.sol";
import "../src/contracts/intent/IntentBondFactory.sol";
import "../src/contracts/intent/SolverBond.sol";
import "../src/contracts/intent/MockIntentOracle.sol";
import "../src/contracts/intent/MockSummerToken.sol";

/**
 * @title DeployIntentSystem
 * @notice Script to deploy the intent-based bond system
 * @dev This script deploys all the required contracts for the intent system
 */
contract DeployIntentSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Intent System...");

        // Deploy MockSummerToken first (needed for factory)
        console.log("Deploying MockSummerToken...");
        MockSummerToken summerToken = new MockSummerToken();
        console.log("MockSummerToken deployed at:", address(summerToken));

        // Deploy IntentBondFactory
        console.log("Deploying IntentBondFactory...");
        IntentBondFactory intentBondFactory = new IntentBondFactory(
            address(summerToken)
        );
        console.log(
            "IntentBondFactory deployed at:",
            address(intentBondFactory)
        );

        // Deploy MockIntentOracle
        console.log("Deploying MockIntentOracle...");
        MockIntentOracle mockOracle = new MockIntentOracle();
        console.log("MockIntentOracle deployed at:", address(mockOracle));

        // Deploy IntentHandler
        console.log("Deploying IntentHandler...");
        IntentHandler intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(mockOracle)
        );
        console.log("IntentHandler deployed at:", address(intentHandler));

        // Setup permissions
        console.log("Setting up permissions...");
        intentBondFactory.grantHandlerRole(address(intentHandler));
        intentBondFactory.grantLiquidatorRole(msg.sender); // Deployer as liquidator
        mockOracle.addSupportedToken(address(summerToken));
        mockOracle.setPrice(address(summerToken), 1e18, 18); // $1.00 per token

        console.log("Intent System deployment complete!");
        console.log("IntentBondFactory:", address(intentBondFactory));
        console.log("MockIntentOracle:", address(mockOracle));
        console.log("IntentHandler:", address(intentHandler));
        console.log("MockSummerToken:", address(summerToken));

        vm.stopBroadcast();
    }
}
