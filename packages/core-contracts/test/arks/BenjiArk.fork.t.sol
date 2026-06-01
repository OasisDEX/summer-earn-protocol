// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/BenjiArk.sol";
import {ISwapPool} from "../../src/interfaces/benji/ISwapPool.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

/// @notice Owner-only SwapPool surface used to onboard the Ark as a trader on the fork.
interface ISwapPoolAdmin {
    function owner() external view returns (address);

    function authorizeTrader(
        address trader,
        address tokenA,
        address tokenB
    ) external;
}

/// @notice iBENJI AuthorizationModule surface used to onboard the Ark as a KYC'd holder on the fork.
interface IBenjiAuthModule {
    function authorizeAccount(address account) external;

    function isAccountAuthorized(address account) external view returns (bool);
}

/**
 * @title BenjiArk fork test — Franklin Templeton iBENJI on Ethereum mainnet
 * @notice Validates the BenjiArk wiring AND a genuine end-to-end board/disembark against the REAL
 *         iBENJI token and Franklin-Templeton SwapPool. Onboarding the Ark needs two privileged
 *         actions — both impersonated on the fork via `vm.prank` (no private key required, à la
 *         SyrupArk's `setLenderAllowlist`):
 *           1. SwapPool owner authorizes the Ark as a trader for the USDC/iBENJI pair.
 *           2. iBENJI's AuthorizationModule admin authorizes the Ark as a KYC'd holder (so the
 *              SwapPool's iBENJI delivery passes the token's transfer policy).
 *
 * @dev Confirmed against mainnet @ block 25222568: stable leg is USDC (6 dec), iBENJI is 18 dec;
 *      both registered and the USDC/iBENJI pair authorized with per-trader auth enforced;
 *      lastKnownPrice == 1e18 ($1 par). Privileged addresses discovered on-chain (pinned to the
 *      fork block): SwapPool owner, iBENJI module registry -> AuthorizationModule -> its
 *      ROLE_AUTHORIZATION_ADMIN member.
 */
contract BenjiArkForkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    BenjiArk public ark;
    ArkParams public params;

    // Ethereum mainnet (from .resources/benji/info.md).
    address constant SWAP_POOL = 0x2e508F0F89Ce077252b182f37Aa20240f7b5eC2f;
    address constant IBENJI = 0x90276e9d4A023b5229E0C2e9D4b2a83fe3A2b48c;
    address constant STABLE = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (confirmed leg)

    // Privileged addresses discovered on-chain at the fork block (see contract NatSpec).
    address constant SWAP_POOL_OWNER =
        0x7687DA958f1b8799B8b0Df39D2f2d729CF3D85Bf;
    address constant IBENJI_AUTH_MODULE =
        0x12aBfF8Dca2d09D99019dFCC9bf07539a8264066;
    address constant IBENJI_AUTH_ADMIN =
        0xe9cAc1Be0dfCaf655E0193385800B9DaF9B723E2;

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
        assertEq(ark.assetDecimals(), 6, "USDC decimals");
        assertEq(ark.shareDecimals(), 18, "iBENJI decimals");
        assertEq(IERC20Metadata(STABLE).decimals(), 6);
        assertEq(IERC20Metadata(IBENJI).decimals(), 18);
    }

    function test_Fork_PairAuthorizedAndTraderEnforced() public view {
        // The USDC/iBENJI pair is authorized on the live pool (the constructor would have reverted
        // with PairNotAuthorized otherwise)...
        assertTrue(ISwapPool(SWAP_POOL).isTokenPairAuthorized(STABLE, IBENJI));
        // ...but per-trader authorization is enforced: an arbitrary address cannot trade the pair,
        // so this Ark must be explicitly authorized by Franklin Templeton (see isArkOnboarded).
        assertFalse(
            ISwapPool(SWAP_POOL).isTraderAllowed(
                address(0xdead),
                STABLE,
                IBENJI
            )
        );
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

    /// @dev Grant the Ark the two off-chain prerequisites by impersonating the privileged accounts:
    ///      SwapPool trader authorization and iBENJI holder authorization.
    function _onboardArk() internal {
        vm.prank(SWAP_POOL_OWNER);
        ISwapPoolAdmin(SWAP_POOL).authorizeTrader(address(ark), STABLE, IBENJI);

        vm.prank(IBENJI_AUTH_ADMIN);
        IBenjiAuthModule(IBENJI_AUTH_MODULE).authorizeAccount(address(ark));
    }

    function test_Fork_OnboardingPrereqs() public {
        _onboardArk();
        assertTrue(ark.isArkOnboarded(), "Ark is now an authorized trader");
        assertTrue(
            IBenjiAuthModule(IBENJI_AUTH_MODULE).isAccountAuthorized(
                address(ark)
            ),
            "Ark is now an authorized iBENJI holder"
        );
    }

    /// @notice Genuine end-to-end swap against the real SwapPool + iBENJI: board USDC -> iBENJI,
    ///         then disembark iBENJI -> USDC, both settled 1:1 by the live pool.
    function test_Fork_RealBoardAndDisembark() public {
        _onboardArk();
        uint256 amount = 1000 * 1e6; // 1000 USDC

        deal(STABLE, commander, amount);
        vm.startPrank(commander);
        IERC20(STABLE).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Board swapped USDC -> iBENJI 1:1 (6 -> 18 dec). The Ark now holds ~1000 iBENJI valued at
        // ~1000 USDC, and holds no idle USDC.
        assertApproxEqAbs(
            IERC20(IBENJI).balanceOf(address(ark)),
            1000 * 1e18,
            1e12,
            "Ark holds ~1000 iBENJI"
        );
        assertEq(IERC20(STABLE).balanceOf(address(ark)), 0, "no idle USDC");
        assertApproxEqAbs(ark.totalAssets(), amount, 1, "valued at par");

        // Disembark swaps iBENJI -> USDC 1:1 and forwards `amount` to the commander.
        uint256 commanderBefore = IERC20(STABLE).balanceOf(commander);
        vm.prank(commander);
        ark.disembark(amount, bytes(""));

        assertEq(
            IERC20(STABLE).balanceOf(commander),
            commanderBefore + amount,
            "commander received USDC back"
        );
        assertApproxEqAbs(
            IERC20(IBENJI).balanceOf(address(ark)),
            0,
            1e12,
            "Ark exited iBENJI"
        );
    }
}
