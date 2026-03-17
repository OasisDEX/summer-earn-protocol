// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/WisdomTreeArk.sol";
import {AssetsForwarder} from "../../src/utils/AssetsForwarder/AssetsForwarder.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";

contract WisdomTreeArkBaseForkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    WisdomTreeArk public ark;
    AssetsForwarder public forwarder;
    IERC20 public usdc;
    IERC20 public wtToken;
    AggregatorV3Interface public oracle;
    ArkParams public params;

    address public constant USDC_ADDRESS =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    address public constant TARGET_WALLET =
        0xa6fe9331eae8DFfA4A4fE93c8B8544653856E882;
    address public constant SHARE_TOKEN =
        0xCf997c6A8DbdC1449e4dDE59Dbdf9cf6dA9d41c1;
    address public constant ORACLE = 0x872E73cC259a025f089CEcF525cc657a9D521af3;

    uint256 forkBlock = 43227198;
    uint256 forkId;

    function setUp() public {
        // We use the base rpc url configured in foundry.toml
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        initializeCoreContracts();

        usdc = IERC20(USDC_ADDRESS);
        wtToken = IERC20(SHARE_TOKEN);
        oracle = AggregatorV3Interface(ORACLE);
        keeper = makeAddr("keeper");

        params = ArkParams({
            name: "USDC WisdomTree Ark",
            details: "USDC WisdomTree Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        forwarder = new AssetsForwarder(address(accessManager));
        accessManager.grantKeeperRole(address(forwarder), keeper);
        forwarder.setWhitelisted(TARGET_WALLET, true);
        ark = new WisdomTreeArk(
            TARGET_WALLET,
            SHARE_TOKEN,
            ORACLE,
            address(forwarder),
            WisdomTreeArk.WTArkType.NonMoneyMarket,
            params
        );
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_BaseFork_OraclePrice_And_SharesToAssets() public {
        (, int256 answer, , , ) = oracle.latestRoundData();

        // Oracle decimals are 8 (typically for USD pairs)
        uint8 oracleDecimals = oracle.decimals();
        console.log("Oracle Decimals:", oracleDecimals);
        console.log("Oracle raw answer:", answer);

        // Verify the expected roughly 10.2352 scaled (1023520000)
        // give or take some small drift depending on the exact block but it should be very close to 10.2352
        // We just ensure it's around 10.23 * 1e8
        assertEq(
            answer,
            (102353 * int256(10 ** oracleDecimals)) / 10000,
            "Oracle price does not match expected value"
        );

        // Now test sharesToAssets functionality on the ark using 1 share = 1e18
        uint256 oneShare = 1e18;
        uint256 expectedAssets = ark.sharesToAssets(oneShare);

        console.log("Expected Assets for 1 share:", expectedAssets);

        // Expected USDC is 10.2352 USDC (with 6 decimals) = 10235200
        // We ensure it is roughly 10.23 USDC
        assertEq(expectedAssets, 10235300);

        // Detailed check if answer is exactly 1023520000:
        // answer has 8 decimals.
        // answer = 1023520000
        // Expected USDC = answer * 1e6 / 1e8 = 10235200
        uint256 calculatedExpected = (uint256(answer) * (10 ** 6)) / (10 ** 8);
        assertEq(
            expectedAssets,
            calculatedExpected,
            "sharesToAssets did not match expected price conversion"
        );
    }
}
