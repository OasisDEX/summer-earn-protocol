// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BenjiArk} from "../../src/contracts/arks/BenjiArk.sol";
import {IBenjiArkErrors} from "../../src/errors/arks/IBenjiArkErrors.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ISwapPool} from "../../src/interfaces/benji/ISwapPool.sol";
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
 * @notice End-to-end board/disembark test against production iBENJI and SwapPools. Requires two
 *         on-chain onboarding steps: SwapPool owner authorizes the Ark as a trader for the
 *         USDC/iBENJI pair; iBENJI's AuthorizationModule admin authorizes the Ark as a holder.
 *
 * @dev Fork block 25222568: USDC (6 dec) and iBENJI (18 dec) authorized on both SwapPools with
 *      per-trader auth enforced; iBENJI lastKnownPrice == 1e18 ($1 par).
 */
contract BenjiArkForkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    BenjiArk public ark;
    ArkParams public params;

    // Ethereum mainnet (from .resources/benji/info.md).
    address constant SWAP_POOL = 0x2e508F0F89Ce077252b182f37Aa20240f7b5eC2f;
    address constant SWAP_POOL_2 = 0xF83B6b38ab056909282EdDb99884e2a079E85F8b;
    address constant IBENJI = 0x90276e9d4A023b5229E0C2e9D4b2a83fe3A2b48c;
    address constant STABLE = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (confirmed leg)

    // Privileged addresses discovered on-chain at the fork block (see contract NatSpec).
    address constant SWAP_POOL_OWNER =
        0x7687DA958f1b8799B8b0Df39D2f2d729CF3D85Bf;
    address constant IBENJI_AUTH_MODULE =
        0x12aBfF8Dca2d09D99019dFCC9bf07539a8264066;
    address constant IBENJI_AUTH_ADMIN =
        0xe9cAc1Be0dfCaf655E0193385800B9DaF9B723E2;

    /// @dev Dust tolerance for 18-decimal iBENJI comparisons (1e12 wei of iBENJI == 1e-6 USDC).
    uint256 constant SHARE_DUST_TOLERANCE = 1e12;

    uint256 forkBlock = 25222568;

    function setUp() public {
        // The fork must be created BEFORE initializeCoreContracts() so the core
        // contracts are deployed on the active fork.
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

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
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = new BenjiArk(
            IBENJI,
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        accessManager.grantCuratorRole(address(commander), address(curator));
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();

        vm.startPrank(curator);
        ark.whitelistSwapPool(SWAP_POOL, true);
        ark.whitelistSwapPool(SWAP_POOL_2, true);
        vm.stopPrank();
    }

    function test_Fork_ConstructorWiring() public view {
        assertEq(address(ark.shareToken()), IBENJI);
        assertEq(address(ark.asset()), STABLE);
        assertTrue(ark.whitelistedSwapPools(SWAP_POOL));
        assertTrue(ark.whitelistedSwapPools(SWAP_POOL_2));
    }

    function test_Fork_Decimals() public view {
        assertEq(ark.assetDecimals(), 6, "USDC decimals");
        assertEq(ark.shareDecimals(), 18, "iBENJI decimals");
        assertEq(IERC20Metadata(STABLE).decimals(), 6);
        assertEq(IERC20Metadata(IBENJI).decimals(), 18);
    }

    function test_Fork_PairAuthorizedAndTraderEnforced() public view {
        assertTrue(ISwapPool(SWAP_POOL).isTokenPairAuthorized(STABLE, IBENJI));
        assertTrue(
            ISwapPool(SWAP_POOL_2).isTokenPairAuthorized(STABLE, IBENJI)
        );
        assertFalse(
            ISwapPool(SWAP_POOL).isTraderAllowed(
                address(0xdead),
                STABLE,
                IBENJI
            )
        );
    }

    function test_Fork_ArkNotOnboarded() public view {
        // A freshly deployed Ark is not an authorized trader on either SwapPool.
        assertFalse(ark.isArkOnboarded(SWAP_POOL));
        assertFalse(ark.isArkOnboarded(SWAP_POOL_2));
    }

    function test_Fork_BoardRevertsWhenNotAuthorized() public {
        uint256 amount = 1000 * 1e6;
        deal(STABLE, commander, amount);
        vm.startPrank(commander);
        IERC20(STABLE).approve(address(ark), amount);
        vm.expectRevert(IBenjiArkErrors.ArkNotAuthorized.selector);
        ark.board(amount, abi.encode(SWAP_POOL));
        vm.stopPrank();
    }

    function test_Fork_BoardRevertsOnNonWhitelistedPool() public {
        uint256 amount = 1000 * 1e6;
        deal(STABLE, commander, amount);
        vm.startPrank(commander);
        IERC20(STABLE).approve(address(ark), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBenjiArkErrors.SwapPoolNotWhitelisted.selector,
                address(0xdead)
            )
        );
        ark.board(amount, abi.encode(address(0xdead)));
        vm.stopPrank();
    }

    /// @dev Grant the Ark the off-chain prerequisites by impersonating the privileged accounts:
    ///      trader authorization on both SwapPools and iBENJI holder authorization.
    function _onboardArk() internal {
        vm.startPrank(SWAP_POOL_OWNER);
        ISwapPoolAdmin(SWAP_POOL).authorizeTrader(address(ark), STABLE, IBENJI);
        ISwapPoolAdmin(SWAP_POOL_2).authorizeTrader(
            address(ark),
            STABLE,
            IBENJI
        );
        vm.stopPrank();

        vm.prank(IBENJI_AUTH_ADMIN);
        IBenjiAuthModule(IBENJI_AUTH_MODULE).authorizeAccount(address(ark));
    }

    function test_Fork_OnboardingPrereqs() public {
        _onboardArk();
        assertTrue(ark.isArkOnboarded(SWAP_POOL), "trader gate on pool 1");
        assertTrue(ark.isArkOnboarded(SWAP_POOL_2), "trader gate on pool 2");
        assertTrue(
            IBenjiAuthModule(IBENJI_AUTH_MODULE).isAccountAuthorized(
                address(ark)
            ),
            "iBENJI holder authorization"
        );
    }

    /// @notice End-to-end swap: board USDC -> iBENJI through pool 1, then disembark iBENJI ->
    ///         USDC through pool 2.
    function test_Fork_RealBoardAndDisembark_AcrossPools() public {
        _onboardArk();
        uint256 amount = 1000 * 1e6; // 1000 USDC

        deal(STABLE, commander, amount);
        vm.startPrank(commander);
        IERC20(STABLE).approve(address(ark), amount);
        ark.board(amount, abi.encode(SWAP_POOL));
        vm.stopPrank();

        assertApproxEqAbs(
            IERC20(IBENJI).balanceOf(address(ark)),
            1000 * 1e18,
            SHARE_DUST_TOLERANCE,
            "Ark holds ~1000 iBENJI"
        );
        assertEq(IERC20(STABLE).balanceOf(address(ark)), 0, "no idle USDC");
        assertApproxEqAbs(ark.totalAssets(), amount, 1, "valued at par");

        uint256 commanderBefore = IERC20(STABLE).balanceOf(commander);
        vm.prank(commander);
        ark.disembark(amount, abi.encode(SWAP_POOL_2));

        assertEq(
            IERC20(STABLE).balanceOf(commander),
            commanderBefore + amount,
            "commander received USDC back"
        );
        assertApproxEqAbs(
            IERC20(IBENJI).balanceOf(address(ark)),
            0,
            SHARE_DUST_TOLERANCE,
            "Ark exited iBENJI"
        );
    }
}
