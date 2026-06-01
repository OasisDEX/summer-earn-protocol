// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/BenjiArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                   MOCKS                                     */
/* -------------------------------------------------------------------------- */

/// @notice ERC20 with configurable decimals and open mint, used for the stable leg and iBENJI.
contract MockToken is ERC20 {
    uint8 private immutable _dec;

    constructor(string memory n, string memory s, uint8 dec_) ERC20(n, s) {
        _dec = dec_;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Minimal Franklin Templeton SwapPool: 1:1 swap with decimal normalization, a trader-auth
///         gate, an optional underdelivery haircut, and a pause switch. Must be pre-funded with the
///         output-token reserves it pays out (mirroring the contract-held-treasury mode).
contract MockSwapPool {
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
        IERC20(fromToken).transferFrom(msg.sender, address(this), amount);
        uint256 out = _normalize(
            amount,
            ERC20(fromToken).decimals(),
            ERC20(toToken).decimals()
        );
        out = out - (out * haircutBps) / 10000;
        IERC20(toToken).transfer(destination, out);
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

/// @notice Minimal secondary-market router for the `withdrawUsingSwap` escape path. Pulls the sell
///         token from the caller and delivers a fixed amount of the buy token to a recipient.
contract MockRouter {
    function swap(
        address sellToken,
        address buyToken,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external {
        IERC20(sellToken).transferFrom(msg.sender, address(this), amountIn);
        IERC20(buyToken).transfer(to, amountOut);
    }
}

/* -------------------------------------------------------------------------- */
/*                                   TESTS                                     */
/* -------------------------------------------------------------------------- */

contract BenjiArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    BenjiArk public ark;
    BufferArk public bufferArk;
    MockToken public stable; // 6-decimal stable leg (e.g. USC / USDC)
    MockToken public ibenji; // 18-decimal iBENJI share token
    MockSwapPool public pool;
    ArkParams public params;

    uint256 constant ONE = 1000 * 1e6; // 1000 stable units

    function setUp() public {
        initializeCoreContracts();

        stable = new MockToken("Stable", "USC", 6);
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
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = new BenjiArk(
            address(pool),
            address(ibenji),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        vm.stopPrank();

        ArkParams memory bParams = params;
        bParams.name = "BufferArk";
        bufferArk = new BufferArk(bParams, address(commander));

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        accessManager.grantCuratorRole(address(commander), address(curator));
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();
    }

    /* ------------------------------ helpers ------------------------------ */

    function _board(uint256 amount) internal {
        stable.mint(commander, amount);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
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
        assertEq(address(ark.swapPool()), address(pool));
        assertEq(address(ark.shareToken()), address(ibenji));
        assertEq(address(ark.asset()), address(stable));
        assertEq(ark.assetDecimals(), 6);
        assertEq(ark.shareDecimals(), 18);
    }

    function test_Constructor_RevertsZeroChecks() public {
        vm.expectRevert(BenjiArk.InvalidSwapPoolAddress.selector);
        new BenjiArk(
            address(0),
            address(ibenji),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        vm.expectRevert(BenjiArk.InvalidShareTokenAddress.selector);
        new BenjiArk(
            address(pool),
            address(0),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    function test_Constructor_RevertsBadSlippage() public {
        Percentage tooHigh = Percentage.wrap(PERCENTAGE_FACTOR); // 100% > 0.5% cap
        vm.expectRevert(
            abi.encodeWithSelector(
                BenjiArk.InvalidDepositSlippage.selector,
                tooHigh,
                ark.MAX_DEPOSIT_SLIPPAGE()
            )
        );
        new BenjiArk(address(pool), address(ibenji), tooHigh, params);
    }

    function test_Constructor_RevertsUnauthorizedPair() public {
        MockSwapPool unauthPool = new MockSwapPool();
        unauthPool.setPairAuthorized(false);
        vm.expectRevert(BenjiArk.PairNotAuthorized.selector);
        new BenjiArk(
            address(unauthPool),
            address(ibenji),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    /* ----------------------------- onboarding ---------------------------- */

    function test_isArkOnboarded() public {
        pool.setAllowAll(false);
        assertFalse(ark.isArkOnboarded());
        pool.setTraderAllowed(address(ark), true);
        assertTrue(ark.isArkOnboarded());
    }

    function test_Board_RevertsIfArkNotAuthorized() public {
        pool.setAllowAll(false);
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert(BenjiArk.ArkNotAuthorized.selector);
        ark.board(ONE, bytes(""));
        vm.stopPrank();
    }

    /* ------------------------------- board ------------------------------- */

    function test_Board_SwapsToIbenji_AtPar() public {
        _board(ONE);
        // 1000 stable (6dec) -> 1000 iBENJI (18dec) at 1:1 par.
        assertEq(ibenji.balanceOf(address(ark)), 1000 * 1e18);
        assertEq(stable.balanceOf(address(ark)), 0);
        assertEq(ark.totalAssets(), ONE, "valued 1:1 in stable terms");
    }

    function test_Board_RevertsOnUnderdelivery() public {
        pool.setHaircutBps(100); // 1% haircut > 0.5% depositSlippage
        stable.mint(commander, ONE);
        vm.startPrank(commander);
        IERC20(address(stable)).forceApprove(address(ark), ONE);
        vm.expectRevert();
        ark.board(ONE, bytes(""));
        vm.stopPrank();
    }

    /* ----------------------------- disembark ----------------------------- */

    function test_Disembark_SwapsBackToStable() public {
        _board(ONE);
        uint256 commanderBefore = stable.balanceOf(commander);

        vm.prank(commander);
        ark.disembark(ONE, bytes(""));

        assertEq(
            stable.balanceOf(commander),
            commanderBefore + ONE,
            "commander receives stable back"
        );
        assertEq(ibenji.balanceOf(address(ark)), 0);
        assertEq(ark.totalAssets(), 0);
    }

    function test_WithdrawableTotalAssets_IsSynchronous() public {
        _board(ONE);
        // SwapPool redemption is synchronous, so all held value is withdrawable.
        assertEq(ark.withdrawableTotalAssets(), ONE);
        assertEq(ark.assetsInWithdrawalQueue(), 0);
        assertFalse(ark.isWithdrawalClaimRequired());
    }

    /* --------------------------- escape swap ----------------------------- */

    function test_WithdrawUsingSwap_ViaWhitelistedRouter() public {
        _board(ONE);

        MockRouter router = new MockRouter();
        stable.mint(address(router), ONE); // router pays out stable

        vm.prank(curator);
        ark.whitelistRouter(address(router), true);

        _mockCommanderBuffer();

        uint256 shares = 1000 * 1e18;
        bytes memory swapCalldata = abi.encodeCall(
            MockRouter.swap,
            (address(ibenji), address(stable), shares, ONE, address(ark))
        );
        bytes memory data = abi.encode(
            IArkWithWithdrawalRequest.SwapData({
                router: address(router),
                swapCalldata: swapCalldata
            })
        );

        vm.prank(keeper);
        ark.withdrawUsingSwap(ONE, data);

        assertEq(ibenji.balanceOf(address(ark)), 0, "iBENJI sold");
        assertEq(
            stable.balanceOf(address(bufferArk)),
            ONE,
            "proceeds buffered"
        );
    }

    function test_WithdrawUsingSwap_RevertsNonWhitelistedRouter() public {
        _board(ONE);
        bytes memory data = abi.encode(
            IArkWithWithdrawalRequest.SwapData({
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
        // 1 iBENJI (1e18) == 1 stable (1e6) at par.
        assertEq(ark.sharesToAssets(1e18), 1e6);
        assertEq(ark.sharesToAssets(1000 * 1e18), 1000 * 1e6);
    }

    /* ----------------------------- slippage ------------------------------ */

    function test_SetDepositSlippage() public {
        Percentage newSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 4); // 0.25%
        vm.prank(keeper);
        ark.setDepositSlippage(newSlippage);
        assertEq(
            Percentage.unwrap(ark.depositSlippage()),
            Percentage.unwrap(newSlippage)
        );
    }

    function test_SetDepositSlippage_RevertsAboveMax() public {
        Percentage tooHigh = Percentage.wrap(PERCENTAGE_FACTOR);
        Percentage maxSlippage = ark.MAX_DEPOSIT_SLIPPAGE();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                BenjiArk.InvalidDepositSlippage.selector,
                tooHigh,
                maxSlippage
            )
        );
        ark.setDepositSlippage(tooHigh);
    }
}
