// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/BenjiArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title BenjiArk fork test — Franklin Templeton iBENJI on Ethereum mainnet
 * @notice Validates the BenjiArk wiring against the REAL iBENJI token and the Franklin-Templeton
 *         SwapPool. The full board -> disembark cycle requires this Ark to be onboarded as an
 *         authorized SwapPool trader (an owner-only operation we cannot reproduce on a fork without
 *         the privileged key); that cycle is covered by the mock-based unit tests in BenjiArk.t.sol.
 *         Here we assert the real integration points: live decimals, the trader-authorization gate,
 *         and that an un-onboarded Ark is blocked from boarding.
 *
 * @dev SCAFFOLD CAVEAT (open question #1): the stable leg of the iBENJI SwapPool ("USC") is not yet
 *      confirmed. USDC is used here as a placeholder asset so the constructor/onboarding gate can be
 *      exercised; the assertions below hold regardless of the real leg. Replace `STABLE` with the
 *      confirmed leg during iteration and extend with an onboarded board/disembark cycle (impersonate
 *      the SwapPool owner to authorize the Ark as a trader).
 */
contract BenjiArkForkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    BenjiArk public ark;
    ArkParams public params;

    // Ethereum mainnet (from .resources/benji/info.md).
    address constant SWAP_POOL = 0x2e508F0F89Ce077252b182f37Aa20240f7b5eC2f;
    address constant IBENJI = 0x90276e9d4A023b5229E0C2e9D4b2a83fe3A2b48c;
    address constant STABLE = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC placeholder

    uint256 forkBlock = 25222568;

    function setUp() public {
        initializeCoreContracts();
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        keeper = makeAddr("keeper");

        params = ArkParams({
            name: "Benji iBENJI Ark",
            details: "Franklin Templeton iBENJI Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: STABLE,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = new BenjiArk(
            SWAP_POOL,
            IBENJI,
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();
    }

    function test_Fork_ConstructorWiring() public view {
        assertEq(address(ark.swapPool()), SWAP_POOL);
        assertEq(address(ark.shareToken()), IBENJI);
        assertEq(address(ark.asset()), STABLE);
    }

    function test_Fork_Decimals() public view {
        assertEq(ark.assetDecimals(), IERC20Metadata(STABLE).decimals());
        assertEq(ark.shareDecimals(), IERC20Metadata(IBENJI).decimals());
    }

    function test_Fork_ArkNotOnboarded() public view {
        // A freshly deployed Ark is not an authorized SwapPool trader.
        assertFalse(ark.isArkOnboarded());
    }

    function test_Fork_BoardRevertsWhenNotAuthorized() public {
        uint256 amount = 1000 * 1e6;
        deal(STABLE, commander, amount);
        vm.startPrank(commander);
        IERC20(STABLE).approve(address(ark), amount);
        vm.expectRevert(BenjiArk.ArkNotAuthorized.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }
}
