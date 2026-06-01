// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/SecuritizeArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title SecuritizeArk fork test — VanEck Treasury Fund (VBILL) on Ethereum mainnet
 * @notice Validates the SecuritizeArk wiring against the REAL VBILL DSToken, its registry, and the
 *         live RedStone NAV feed. The full board -> clear -> withdraw -> sweep cycle requires the
 *         Ark + custodian to be onboarded as investor wallets by Securitize (an `onlyExchangeOrAbove`
 *         operation we cannot reproduce on a fork without the privileged key); that cycle is covered
 *         by the mock-based unit tests in SecuritizeArk.t.sol. Here we assert the real integration
 *         points: on-chain registry resolution, the live NAV oracle, decimals, par valuation, and
 *         that the real registry gate blocks an un-onboarded Ark.
 */
contract SecuritizeArkForkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    SecuritizeArk public ark;
    BufferArk public bufferArk;
    ArkParams public params;
    address public custodian;

    // Ethereum mainnet (verified 2026-06-01).
    address constant VBILL = 0x2255718832bC9fD3bE1CaF75084F4803DA14FF01;
    address constant NAV_ORACLE = 0xA569E68B5D110F2A255482c2997DFDBe1b2ab912; // VBILL_ETHEREUM_FUNDAMENTAL
    address constant REGISTRY = 0x897e452425bd1c860d7F9bc14eA045cBbC0fA0d4;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 forkBlock = 25222568;

    function setUp() public {
        initializeCoreContracts();
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        custodian = makeAddr("custodian");
        keeper = makeAddr("keeper");

        params = ArkParams({
            name: "USDC Securitize VBILL Ark",
            details: "USDC Securitize VBILL Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = new SecuritizeArk(
            custodian,
            VBILL,
            NAV_ORACLE,
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();
    }

    function test_Fork_RegistryResolvedFromToken() public view {
        assertEq(
            address(ark.registryService()),
            REGISTRY,
            "registry resolved from VBILL.getDSService(4)"
        );
    }

    function test_Fork_Decimals() public view {
        assertEq(ark.assetDecimals(), 6, "USDC decimals");
        assertEq(ark.shareDecimals(), 6, "VBILL decimals");
        assertEq(ark.oracleDecimals(), 8, "RedStone feed decimals");
        assertEq(IERC20Metadata(VBILL).decimals(), 6);
    }

    function test_Fork_LiveNavOracle_ParValuation() public view {
        // VBILL is a $1.00-par fund: 1 VBILL (1e6) ~= 1 USDC (1e6) via the live NAV feed.
        uint256 oneVbill = ark.sharesToAssets(1e6);
        assertApproxEqAbs(oneVbill, 1e6, 1e3, "1 VBILL ~= $1.00 in USDC");

        uint256 thousand = ark.sharesToAssets(1000 * 1e6);
        assertApproxEqAbs(thousand, 1000 * 1e6, 1e6, "1000 VBILL ~= $1000");
    }

    function test_Fork_ArkNotOnboarded() public view {
        // A freshly deployed Ark is not yet a registered investor wallet.
        assertFalse(ark.isArkOnboarded());
    }

    function test_Fork_BoardRevertsAgainstRealRegistry() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC, commander, amount);
        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        // Real registry gate: the Ark is not onboarded, so board must revert.
        vm.expectRevert(SecuritizeArk.ArkNotRegistered.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Fork_ConstructorWiring() public view {
        assertEq(ark.custodianWallet(), custodian);
        assertEq(address(ark.asset()), USDC);
        assertEq(address(ark.shareToken()), VBILL);
        assertEq(address(ark.oracle()), NAV_ORACLE);
    }
}
