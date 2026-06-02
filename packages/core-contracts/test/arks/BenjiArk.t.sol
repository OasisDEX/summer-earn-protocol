// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BenjiArk} from "../../src/contracts/arks/BenjiArk.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {IBenjiArkErrors} from "../../src/errors/arks/IBenjiArkErrors.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IArkWithSwap} from "../../src/interfaces/IArkWithSwap.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                   MOCKS                                     */
/* -------------------------------------------------------------------------- */

/// @notice ERC20 with configurable decimals and open mint, used for the stable leg and iBENJI.
/// @dev Optionally enforces a holder whitelist on transfers to model the token's KYC policy.
contract MockToken is ERC20 {
    uint8 private immutable _dec;
    bool public holderGate;
    mapping(address => bool) public authorizedHolder;

    constructor(string memory n, string memory s, uint8 dec_) ERC20(n, s) {
        _dec = dec_;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setHolderGate(bool v) external {
        holderGate = v;
    }

    function setAuthorizedHolder(address a, bool v) external {
        authorizedHolder[a] = v;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        if (holderGate && from != address(0) && to != address(0)) {
            require(authorizedHolder[to], "HOLDER_NOT_AUTHORIZED");
        }
        super._update(from, to, value);
    }
}

/// @notice Minimal Franklin Templeton SwapPool: 1:1 swap with decimal normalization, trader
///         authorization gate, optional haircut, and pause switch. Must be pre-funded with output
///         token reserves.
contract MockSwapPool {
    uint256 public constant BPS_BASE = 10_000;

    bool public paused;
    bool public allowAll = true;
    bool public pairAuthorized = true;
    uint256 public haircutBps; // simulates SwapPool underdelivery for slippage tests
    mapping(address => bool) public traderAllowed;

    function setPaused(bool v) external {
        paused = v;
    }

    function setAllowAll(bool v) external {
        allowAll = v;
    }

    function setPairAuthorized(bool v) external {
        pairAuthorized = v;
    }

    function setTraderAllowed(address t, bool v) external {
        traderAllowed[t] = v;
    }

    function setHaircutBps(uint256 v) external {
        haircutBps = v;
    }

    function isTraderAllowed(
        address trader,
        address,
        address
    ) external view returns (bool) {
        return allowAll || traderAllowed[trader];
    }

    function isTokenPairAuthorized(
        address,
        address
    ) external view returns (bool) {
        return pairAuthorized;
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function swap(address fromToken, address toToken, uint256 amount) external {
        _swap(fromToken, toToken, amount, msg.sender);
    }

    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        address destination
    ) external {
        _swap(
            fromToken,
            toToken,
            amount,
            destination == address(0) ? msg.sender : destination
        );
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amount,
        address destination
    ) internal {
        require(!paused, "PAUSED");
        require(allowAll || traderAllowed[msg.sender], "UNAUTHORIZED");
        require(
            IERC20(fromToken).transferFrom(msg.sender, address(this), amount),
            "TRANSFER_FROM_FAILED"
        );
        uint256 out = _normalize(
            amount,
            ERC20(fromToken).decimals(),
            ERC20(toToken).decimals()
        );
        out = out - (out * haircutBps) / BPS_BASE;
        require(IERC20(toToken).transfer(destination, out), "TRANSFER_FAILED");
    }

    function _normalize(
        uint256 amount,
        uint8 fromDec,
        uint8 toDec
    ) internal pure returns (uint256) {
        if (fromDec == toDec) return amount;
        if (toDec > fromDec) return amount * (10 ** (toDec - fromDec));
        return amount / (10 ** (fromDec - toDec));
    }
}

/// @notice Minimal secondary-market router for the `withdrawUsingSwap` escape path.
contract MockRouter {
    function swap(
        address sellToken,
        address buyToken,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external {
        require(
            IERC20(sellToken).transferFrom(msg.sender, address(this), amountIn),
            "TRANSFER_FROM_FAILED"
        );
        require(IERC20(buyToken).transfer(to, amountOut), "TRANSFER_FAILED");
    }
}

/* -------------------------------------------------------------------------- */
/*                                   TESTS                                     */
/* -------------------------------------------------------------------------- */

contract BenjiArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    BenjiArk public ark;
    BufferArk public bufferArk;
    MockToken public stable; // 6-decimal stable leg (USDC on mainnet)
    MockToken public ibenji; // 18-decimal iBENJI share token
    MockSwapPool public pool;
    ArkParams public params;

    uint256 constant ONE = 1000 * 1e6; // 1000 stable units (6 decimals)
    uint256 constant ONE_IN_SHARES = 1000 * 1e18; // the same value in iBENJI (18 decimals)

    function setUp() public {
        initializeCoreContracts();

        stable = new MockToken("USD Coin", "USDC", 6);
        ibenji = new MockToken("Franklin iBENJI", "iBENJI", 18);
        pool = new MockSwapPool();

        // Pre-fund the pool so it can pay out either leg of a 1:1 swap.
        ibenji.mint(address(pool), 1_000_000 * 1e18);
        stable.mint(address(pool), 1_000_000 * 1e6);

        params = ArkParams({
            name: "Benji Ark",
            details: "Franklin Templeton iBENJI Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(stable),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = new BenjiArk(
            address(ibenji),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        vm.stopPrank();

        ArkParams memory bParams = params;
        bParams.name = "BufferArk";
        bParams.requiresKeeperData = false;
        bufferArk = new BufferArk(bParams, address(commander));

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        accessManager.grantCuratorRole(address(commander), address(curator));
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();

        vm.prank(curator);
        ark.whitelistSwapPool(address(pool), true);
    }

    /* ------------------------------ helpers ------------------------------ */

    function _poolData() internal view returns (bytes memory) {
        return abi.encode(address(pool));
    }

    function _board(uint256 amount) internal {
        stable.mint(commander, amount);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), amount);
        ark.board(amount, _poolData());
        vm.stopPrank();
    }

    function _mockCommanderBuffer() internal {
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );
    }

    /* ----------------------------- constructor --------------------------- */

    function test_Constructor_Wiring() public view {
        assertEq(address(ark.shareToken()), address(ibenji));
        assertEq(address(ark.asset()), address(stable));
        assertEq(ark.assetDecimals(), 6);
        assertEq(ark.shareDecimals(), 18);
        assertTrue(ark.whitelistedSwapPools(address(pool)));
    }

    function test_Constructor_RevertsZeroShareToken() public {
        vm.expectRevert(IBenjiArkErrors.InvalidShareTokenAddress.selector);
        new BenjiArk(
            address(0),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    function test_Constructor_RevertsWithoutKeeperData() public {
        ArkParams memory badParams = params;
        badParams.requiresKeeperData = false;
        vm.expectRevert(IBenjiArkErrors.MustRequireKeeperData.selector);
        new BenjiArk(
            address(ibenji),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            badParams
        );
    }

    function test_Constructor_RevertsBadSlippage() public {
        Percentage tooHigh = Percentage.wrap(PERCENTAGE_FACTOR); // 100% > 0.5% cap
        vm.expectRevert(
            abi.encodeWithSelector(
                IBenjiArkErrors.InvalidDepositSlippage.selector,
                tooHigh,
                ark.MAX_DEPOSIT_SLIPPAGE()
            )
        );
        new BenjiArk(address(ibenji), tooHigh, params);
    }

    /* --------------------------- pool whitelist -------------------------- */

    function test_WhitelistSwapPool_RevertsZeroAddress() public {
        vm.prank(curator);
        vm.expectRevert(IBenjiArkErrors.InvalidSwapPoolAddress.selector);
        ark.whitelistSwapPool(address(0), true);
    }

    function test_WhitelistSwapPool_RevertsUnauthorizedPair() public {
        MockSwapPool unauthPool = new MockSwapPool();
        unauthPool.setPairAuthorized(false);
        vm.prank(curator);
        vm.expectRevert(IBenjiArkErrors.PairNotAuthorized.selector);
        ark.whitelistSwapPool(address(unauthPool), true);
    }

    function test_WhitelistSwapPool_Removal() public {
        vm.prank(curator);
        ark.whitelistSwapPool(address(pool), false);
        assertFalse(ark.whitelistedSwapPools(address(pool)));

        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBenjiArkErrors.SwapPoolNotWhitelisted.selector,
                address(pool)
            )
        );
        ark.board(ONE, _poolData());
        vm.stopPrank();
    }

    function test_Board_RevertsOnNonWhitelistedPool() public {
        MockSwapPool rogue = new MockSwapPool();
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBenjiArkErrors.SwapPoolNotWhitelisted.selector,
                address(rogue)
            )
        );
        ark.board(ONE, abi.encode(address(rogue)));
        vm.stopPrank();
    }

    function test_Board_RevertsOnEmptyKeeperData() public {
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert();
        ark.board(ONE, bytes(""));
        vm.stopPrank();
    }

    function test_Board_RevertsOnMalformedKeeperData() public {
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert(IBenjiArkErrors.InvalidSwapPoolData.selector);
        ark.board(ONE, hex"deadbeef");
        vm.stopPrank();
    }

    /* ----------------------------- onboarding ---------------------------- */

    function test_isArkOnboarded() public {
        pool.setAllowAll(false);
        assertFalse(ark.isArkOnboarded(address(pool)));
        pool.setTraderAllowed(address(ark), true);
        assertTrue(ark.isArkOnboarded(address(pool)));
    }

    function test_Board_RevertsIfArkNotAuthorized() public {
        pool.setAllowAll(false);
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert(IBenjiArkErrors.ArkNotAuthorized.selector);
        ark.board(ONE, _poolData());
        vm.stopPrank();
    }

    /* ------------------------------- board ------------------------------- */

    function test_Board_SwapsToIbenji_AtPar() public {
        _board(ONE);
        // 1000 stable (6 dec) -> 1000 iBENJI (18 dec) at 1:1 par.
        assertEq(ibenji.balanceOf(address(ark)), ONE_IN_SHARES);
        assertEq(stable.balanceOf(address(ark)), 0);
        assertEq(ark.totalAssets(), ONE, "valued 1:1 in stable terms");
    }

    function test_Board_RevertsWhenArkNotAuthorizedHolder() public {
        ibenji.setHolderGate(true);
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert();
        ark.board(ONE, _poolData());
        vm.stopPrank();

        ibenji.setAuthorizedHolder(address(ark), true);
        _board(ONE);
        assertEq(ibenji.balanceOf(address(ark)), ONE_IN_SHARES);
    }

    function test_Board_RevertsOnUnderdelivery() public {
        pool.setHaircutBps(100); // 1% haircut > 0.5% depositSlippage
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert();
        ark.board(ONE, _poolData());
        vm.stopPrank();
    }

    /* ----------------------------- disembark ----------------------------- */

    function test_Disembark_SwapsBackToStable() public {
        _board(ONE);
        uint256 commanderBefore = stable.balanceOf(commander);

        vm.prank(commander);
        ark.disembark(ONE, _poolData());

        assertEq(
            stable.balanceOf(commander),
            commanderBefore + ONE,
            "commander receives stable back"
        );
        assertEq(ibenji.balanceOf(address(ark)), 0);
        assertEq(ark.totalAssets(), 0);
    }

    function test_Disembark_Partial() public {
        _board(ONE);
        uint256 half = ONE / 2;
        uint256 commanderBefore = stable.balanceOf(commander);

        vm.prank(commander);
        ark.disembark(half, _poolData());

        assertEq(
            stable.balanceOf(commander),
            commanderBefore + half,
            "commander receives the partial amount"
        );
        assertEq(
            ibenji.balanceOf(address(ark)),
            ONE_IN_SHARES / 2,
            "half the iBENJI position remains"
        );
        assertEq(ark.totalAssets(), half, "remaining position valued at par");
    }

    function test_Disembark_FullExitWithDonatedDust() public {
        _board(ONE);
        uint256 dust = 1;
        stable.mint(address(ark), dust);
        uint256 total = ark.totalAssets();
        assertEq(total, ONE + dust);

        uint256 commanderBefore = stable.balanceOf(commander);
        vm.prank(commander);
        ark.disembark(total, _poolData());

        assertEq(stable.balanceOf(commander), commanderBefore + total);
        assertEq(ibenji.balanceOf(address(ark)), 0);
        assertEq(ark.totalAssets(), 0);
    }

    function test_MultiPool_BoardAndDisembarkViaDifferentPools() public {
        MockSwapPool secondPool = new MockSwapPool();
        ibenji.mint(address(secondPool), 1_000_000 * 1e18);
        stable.mint(address(secondPool), 1_000_000 * 1e6);
        vm.prank(curator);
        ark.whitelistSwapPool(address(secondPool), true);

        _board(ONE);

        uint256 commanderBefore = stable.balanceOf(commander);
        vm.prank(commander);
        ark.disembark(ONE, abi.encode(address(secondPool)));

        assertEq(stable.balanceOf(commander), commanderBefore + ONE);
        assertEq(ibenji.balanceOf(address(ark)), 0);
        assertEq(
            ibenji.balanceOf(address(secondPool)),
            1_000_000 * 1e18 + ONE_IN_SHARES,
            "second pool absorbed the iBENJI"
        );
    }

    /* ------------------------- withdrawable assets ----------------------- */

    function test_WithdrawableTotalAssets_ZeroWithKeeperData() public {
        _board(ONE);
        assertEq(ark.withdrawableTotalAssets(), 0);
        assertEq(ark.totalAssets(), ONE, "valuation unaffected");
    }

    /* --------------------------- access control -------------------------- */

    function test_AccessControl_BoardRevertsForNonCommander() public {
        stable.mint(address(this), ONE);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert();
        ark.board(ONE, _poolData());
    }

    function test_AccessControl_DisembarkRevertsForNonCommander() public {
        _board(ONE);
        vm.expectRevert();
        ark.disembark(ONE, _poolData());
    }

    function test_AccessControl_WithdrawUsingSwapRevertsForNonKeeper() public {
        bytes memory data = abi.encode(
            IArkWithSwap.SwapData({
                router: address(0x1234),
                swapCalldata: hex""
            })
        );
        vm.expectRevert();
        ark.withdrawUsingSwap(ONE, data);
    }

    function test_AccessControl_SetDepositSlippageRevertsForNonCurator()
        public
    {
        vm.expectRevert();
        ark.setDepositSlippage(Percentage.wrap(PERCENTAGE_FACTOR / 4));
    }

    function test_AccessControl_WhitelistSwapPoolRevertsForNonCurator() public {
        vm.expectRevert();
        ark.whitelistSwapPool(address(pool), false);
    }

    /* --------------------------- escape swap ----------------------------- */

    function test_WithdrawUsingSwap_ViaWhitelistedRouter() public {
        _board(ONE);

        MockRouter router = new MockRouter();
        stable.mint(address(router), ONE); // router pays out stable

        vm.prank(curator);
        ark.whitelistRouter(address(router), true);

        _mockCommanderBuffer();

        uint256 shares = ONE_IN_SHARES;
        bytes memory swapCalldata = abi.encodeCall(
            MockRouter.swap,
            (address(ibenji), address(stable), shares, ONE, address(ark))
        );
        bytes memory data = abi.encode(
            IArkWithSwap.SwapData({
                router: address(router),
                swapCalldata: swapCalldata
            })
        );

        vm.prank(keeper);
        ark.withdrawUsingSwap(ONE, data);

        assertEq(ibenji.balanceOf(address(ark)), 0, "iBENJI sold");
        assertEq(stable.balanceOf(address(bufferArk)), ONE, "ArkWithSwaped");
    }

    function test_WithdrawUsingSwap_RevertsNonWhitelistedRouter() public {
        _board(ONE);
        bytes memory data = abi.encode(
            IArkWithSwap.SwapData({
                router: address(0x1234),
                swapCalldata: hex""
            })
        );
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("RouterNotWhitelisted()"));
        ark.withdrawUsingSwap(ONE, data);
    }

    /* ---------------------------- valuation ------------------------------ */

    function test_SharesToAssets_Normalizes() public view {
        // 1 ArkWithSwap= 1 stable (1e6) at par.
        assertEq(ark.sharesToAssets(1e18), 1e6);
        assertEq(ark.sharesToAssets(1000 * 1e18), 1000 * 1e6);
    }

    /* ----------------------------- slippage ------------------------------ */

    function test_SetDepositSlippage() public {
        Percentage newSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 4); // 0.25%
        vm.prank(curator);
        ark.setDepositSlippage(newSlippage);
        assertEq(
            Percentage.unwrap(ark.depositSlippage()),
            Percentage.unwrap(newSlippage)
        );
    }

    function test_SetDepositSlippage_RevertsAboveMax() public {
        Percentage tooHigh = Percentage.wrap(PERCENTAGE_FACTOR);
        Percentage maxSlippage = ark.MAX_DEPOSIT_SLIPPAGE();
        vm.prank(curator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBenjiArkErrors.InvalidDepositSlippage.selector,
                tooHigh,
                maxSlippage
            )
        );
        ark.setDepositSlippage(tooHigh);
    }
}
