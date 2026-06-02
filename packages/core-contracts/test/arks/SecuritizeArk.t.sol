// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/SecuritizeArk.sol";
import {ISecuritizeArkErrors} from "../../src/errors/arks/ISecuritizeArkErrors.sol";
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

/// @notice Minimal Securitize-style registry: maps wallets to investor IDs.
contract MockRegistry {
    mapping(address => bool) public registered;
    mapping(address => string) public investorOf;

    function register(address wallet, string memory id) external {
        registered[wallet] = true;
        investorOf[wallet] = id;
    }

    function unregister(address wallet) external {
        registered[wallet] = false;
        investorOf[wallet] = "";
    }

    function isWallet(address a) external view returns (bool) {
        return registered[a];
    }

    function getInvestor(address a) external view returns (string memory) {
        return investorOf[a];
    }
}

/// @notice Minimal Securitize DSToken: compliance-gated ERC20 with a NAV-bearing balance.
/// @dev Transfers (not mint/burn) require both parties registered and the token unpaused —
///      mirroring `getComplianceService().validateTransfer`. `issue` simulates issuer minting.
contract MockDSToken is ERC20 {
    uint8 private immutable _dec;
    MockRegistry public registry;
    bool public paused;
    bool public registryUnset; // when true, getDSService(4) returns address(0)

    uint256 public constant CODE_PAUSED = 10;
    uint256 public constant CODE_NOT_REGISTERED = 20;

    constructor(
        MockRegistry _registry,
        uint8 dec_
    ) ERC20("VanEck Treasury Fund", "VBILL") {
        registry = _registry;
        _dec = dec_;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    /// @dev DS Protocol service resolver; id 4 == registry service.
    function getDSService(uint256 id) external view returns (address) {
        if (id == 4 && !registryUnset) return address(registry);
        return address(0);
    }

    function setRegistryUnset(bool v) external {
        registryUnset = v;
    }

    function setPaused(bool v) external {
        paused = v;
    }

    /// @dev Simulates Securitize issuing tokens to a holder (off-chain settlement).
    function issue(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function preTransferCheck(
        address from,
        address to,
        uint256
    ) external view returns (uint256 code, string memory reason) {
        if (paused) return (CODE_PAUSED, "Token paused");
        if (!registry.isWallet(from))
            return (CODE_NOT_REGISTERED, "Wallet not in registry service");
        if (!registry.isWallet(to))
            return (CODE_NOT_REGISTERED, "Wallet not in registry service");
        return (0, "Valid");
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        // Only gate genuine transfers (mint has from==0, burn has to==0).
        if (from != address(0) && to != address(0)) {
            require(!paused, "Token paused");
            require(registry.isWallet(from), "Wallet not in registry service");
            require(registry.isWallet(to), "Wallet not in registry service");
        }
        super._update(from, to, value);
    }
}

/// @notice Chainlink-compatible mock oracle (matches the RedStone push feed VBILL uses).
contract MockOracle is AggregatorV3Interface {
    uint8 public _decimals;
    int256 public _answer;
    uint80 public _roundId = 1;
    uint256 public _updatedAt;
    uint80 public _answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        _decimals = decimals_;
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _updatedAt = block.timestamp;
    }

    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundId = roundId;
        _answer = answer;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock VBILL NAV";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    )
        external
        pure
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert();
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }
}

/* -------------------------------------------------------------------------- */
/*                                   TESTS                                     */
/* -------------------------------------------------------------------------- */

contract SecuritizeArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    SecuritizeArk public ark;
    BufferArk public bufferArk;
    IERC20 public usdc;
    MockRegistry public registry;
    MockDSToken public vbill;
    MockOracle public oracle;
    ArkParams public params;

    // Mainnet USDC (6 decimals), matching VBILL's base asset.
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public custodian;

    uint256 forkBlock = 21666256;

    function setUp() public {
        // Fork must be selected BEFORE initializeCoreContracts() so the core contracts are
        // deployed on the active fork (ark-development skill: fork-test setup order).
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

        usdc = IERC20(USDC_ADDRESS);
        custodian = makeAddr("custodian");
        keeper = makeAddr("keeper");

        registry = new MockRegistry();
        // VBILL has 6 decimals, same as USDC.
        vbill = new MockDSToken(registry, 6);
        // NAV feed: 8 decimals, $1.00 par => 1 VBILL (1e6) == 1 USDC (1e6).
        oracle = new MockOracle(8, 1e8);

        params = ArkParams({
            name: "USDC Securitize VBILL Ark",
            details: "USDC Securitize VBILL Ark details",
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
        ark = new SecuritizeArk(
            custodian,
            address(vbill),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
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
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();
    }

    /* ------------------------------ helpers ------------------------------ */

    function _onboard() internal {
        registry.register(address(ark), "ARK_INVESTOR");
        registry.register(custodian, "CUSTODIAN_INVESTOR");
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

    function _board(uint256 amount) internal {
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    /* ----------------------------- constructor --------------------------- */

    function test_Constructor_ResolvesRegistryFromToken() public view {
        assertEq(
            address(ark.registryService()),
            address(registry),
            "registry resolved from token getDSService(4)"
        );
        assertEq(ark.custodianWallet(), custodian);
        assertEq(address(ark.asset()), USDC_ADDRESS);
    }

    function test_Constructor_RevertsZeroChecks() public {
        vm.expectRevert(ISecuritizeArkErrors.InvalidTargetWallet.selector);
        new SecuritizeArk(
            address(0),
            address(vbill),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        vm.expectRevert(ISecuritizeArkErrors.InvalidShareTokenAddress.selector);
        new SecuritizeArk(
            custodian,
            address(0),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    function test_Constructor_RevertsIfTokenHasNoRegistry() public {
        MockDSToken noReg = new MockDSToken(registry, 6);
        noReg.setRegistryUnset(true);
        vm.expectRevert(ISecuritizeArkErrors.InvalidRegistryAddress.selector);
        new SecuritizeArk(
            custodian,
            address(noReg),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    /* ------------------------------ onboarding --------------------------- */

    function test_isArkOnboarded() public {
        assertFalse(ark.isArkOnboarded());
        _onboard();
        assertTrue(ark.isArkOnboarded());
    }

    function test_Board_RevertsIfArkNotRegistered() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(ISecuritizeArkErrors.ArkNotRegistered.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    /* -------------------------- deposit lifecycle ------------------------ */

    function test_Board_And_PendingDeposit() public {
        _onboard();
        uint256 amount = 1000 * 1e6;
        uint256 custBefore = usdc.balanceOf(custodian);

        _board(amount);

        assertEq(
            usdc.balanceOf(custodian),
            custBefore + amount,
            "custodian receives USDC"
        );
        assertEq(ark.pendingDepositAssets(), amount);
        assertEq(ark.totalAssets(), amount, "pending deposit counts at par");
    }

    function test_ClearPendingDeposit() public {
        _onboard();
        uint256 amount = 1000 * 1e6;
        _board(amount);

        // Securitize issues VBILL to the Ark (1:1 at $1.00 par).
        vbill.issue(address(ark), 1000 * 1e6);

        vm.prank(keeper);
        ark.clearPendingDeposit();

        assertEq(ark.pendingDepositAssets(), 0);
        assertEq(ark.totalAssets(), amount, "value transitions to held VBILL");
    }

    function test_RequestWithdrawal_And_Sweep() public {
        _onboard();
        uint256 amount = 1000 * 1e6;
        _board(amount);
        vbill.issue(address(ark), 1000 * 1e6);

        vm.prank(keeper);
        ark.clearPendingDeposit();

        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        assertEq(
            vbill.balanceOf(custodian),
            1000 * 1e6,
            "VBILL sent to custodian"
        );
        assertEq(vbill.balanceOf(address(ark)), 0);
        assertEq(ark.pendingWithdrawalShares(), 1000 * 1e6);

        // USDC returns from Securitize.
        deal(USDC_ADDRESS, address(ark), amount);
        _mockCommanderBuffer();

        vm.prank(keeper);
        ark.sweep();

        assertEq(ark.pendingWithdrawalShares(), 0);
        assertEq(usdc.balanceOf(address(bufferArk)), amount);
        assertEq(ark.totalAssets(), 0);
    }

    function test_RequestWithdrawal_RevertsIfCustodianNotCompliant() public {
        // Onboard only the Ark, not the custodian.
        registry.register(address(ark), "ARK_INVESTOR");
        uint256 amount = 1000 * 1e6;
        _board(amount);
        vbill.issue(address(ark), 1000 * 1e6);
        vm.prank(keeper);
        ark.clearPendingDeposit();

        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecuritizeArkErrors.TransferNotCompliant.selector,
                vbill.CODE_NOT_REGISTERED(),
                "Wallet not in registry service"
            )
        );
        ark.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function test_RequestWithdrawal_RevertsIfTokenPaused() public {
        _onboard();
        uint256 amount = 1000 * 1e6;
        _board(amount);
        vbill.issue(address(ark), 1000 * 1e6);
        vm.prank(keeper);
        ark.clearPendingDeposit();

        vbill.setPaused(true);

        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecuritizeArkErrors.TransferNotCompliant.selector,
                vbill.CODE_PAUSED(),
                "Token paused"
            )
        );
        ark.requestWithdrawal(amount);
        vm.stopPrank();
    }

    /* ---------------------------- rebasing ------------------------------- */

    function test_ClearPendingDeposit_AbsorbsDailyAccrualRebase() public {
        _onboard();
        uint256 amount = 1000 * 1e6;
        _board(amount);

        // Securitize issues VBILL, then a daily accrual rebase mints a tiny extra
        // (~0.0094%/day) — well within the 0.5% depositSlippage tolerance.
        vbill.issue(address(ark), 1000 * 1e6);
        vbill.issue(address(ark), (1000 * 1e6 * 94) / 1_000_000); // +0.0094%

        vm.prank(keeper);
        ark.clearPendingDeposit(); // should not revert

        assertEq(ark.pendingDepositAssets(), 0);
    }

    /* ----------------------------- freeze -------------------------------- */

    function test_RevertBoardWhenFrozen() public {
        _onboard();
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(ISecuritizeArkErrors.ArkIsFrozen.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    /* ---------------------------- oracle --------------------------------- */

    function test_RevertIfOraclePriceNotPositive() public {
        oracle.setAnswer(0);
        vm.expectRevert(ISecuritizeArkErrors.OraclePriceNotPositive.selector);
        ark.sharesToAssets(1e6);
    }

    function test_RevertIfOracleStale() public {
        oracle.setRoundData(1, 1e8, block.timestamp - 24 hours - 1, 1);
        vm.expectRevert(ISecuritizeArkErrors.StaleOraclePrice.selector);
        ark.sharesToAssets(1e6);
    }

    function test_ParValuation() public view {
        // 1 VBILL (1e6) == $1.00 == 1 USDC (1e6)
        assertEq(ark.sharesToAssets(1e6), 1e6);
        assertEq(ark.sharesToAssets(1000 * 1e6), 1000 * 1e6);
    }

    /* ------------------------- variable NAV (ACRED/STAC) ----------------- */

    /// @notice Funds like ACRED (~$1097/share) and STAC (~$1019/share) are variable-NAV, not par.
    ///         The generic oracle path must value 1 share at the live NAV.
    function test_VariableNavValuation() public {
        // ACRED-style NAV: $1097.96093 at 8 decimals.
        int256 nav = 109796093000;
        oracle.setAnswer(nav);

        // 1 share (1e6) -> answer * 1e6(asset) / 1e8(oracle) USDC units.
        uint256 expectedOneShare = (uint256(nav) * 1e6) / 1e8;
        assertEq(ark.sharesToAssets(1e6), expectedOneShare, "1 share == NAV");
        assertEq(ark.sharesToAssets(10 * 1e6), 10 * expectedOneShare);
    }

    /// @notice Full deposit cycle at a variable NAV: 10 shares issued at ~$1097 each.
    function test_VariableNav_BoardClearWithdraw() public {
        int256 nav = 109796093000; // $1097.96093
        oracle.setAnswer(nav);
        _onboard();

        // Board the USDC value of 10 shares.
        uint256 shares = 10 * 1e6;
        uint256 navValue = (uint256(nav) * shares) / 1e8;
        _board(navValue);

        vbill.issue(address(ark), shares);
        vm.prank(keeper);
        ark.clearPendingDeposit();

        assertEq(ark.pendingDepositAssets(), 0);
        assertApproxEqAbs(
            ark.totalAssets(),
            navValue,
            1,
            "NAV-priced holdings"
        );

        vm.prank(keeper);
        ark.requestWithdrawal(navValue);
        assertEq(
            vbill.balanceOf(custodian),
            shares,
            "shares sent to custodian"
        );
    }

    /* ------------------------- access control ---------------------------- */

    function test_AccessControl() public {
        _onboard();
        address rando = makeAddr("rando");

        // board: only commander (or authorized) may board.
        vm.startPrank(rando);
        vm.expectRevert();
        ark.board(1e6, bytes(""));

        // keeper-only entry points.
        vm.expectRevert();
        ark.requestWithdrawal(1e6);
        vm.expectRevert();
        ark.sweep();
        vm.expectRevert();
        ark.clearPendingDeposit();
        vm.expectRevert();
        ark.setCustodianWallet(rando);
        vm.expectRevert();
        ark.setArkFrozen(true, 0);

        // governor-only entry points.
        vm.expectRevert();
        ark.emergencySweep();
        vm.expectRevert();
        ark.emergencyClearPendingDeposit(1);
        vm.stopPrank();
    }

    /* --------------------------- async no-ops ---------------------------- */

    function test_AsyncNoOpsAndViews() public {
        // claimWithdrawal: keeper-only no-op (off-chain settlement).
        vm.startPrank(keeper);
        ark.claimWithdrawal();

        // withdrawUsingSwap: no-op (no swap-based exit for custodial settlement).
        ark.withdrawUsingSwap(1e6, new bytes(0));
        vm.stopPrank();

        // Async view surface.
        assertEq(ark.withdrawalRequestId(), 0);
        assertFalse(ark.isWithdrawalClaimRequired());
        assertEq(ark.assetsInWithdrawalQueue(), 0);
    }

    /// @notice `withdrawableTotalAssets` must stay 0 throughout the async cycle — funds only
    ///         leave via the keeper-driven `sweep`, never via synchronous `disembark`.
    function test_WithdrawableTotalAssets_AlwaysZero() public {
        assertEq(ark.withdrawableTotalAssets(), 0);

        _onboard();
        uint256 amount = 1000 * 1e6;
        _board(amount);
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "zero while pending deposit"
        );

        vbill.issue(address(ark), 1000 * 1e6);
        vm.prank(keeper);
        ark.clearPendingDeposit();
        assertEq(ark.withdrawableTotalAssets(), 0, "zero while holding shares");

        vm.prank(keeper);
        ark.requestWithdrawal(amount);
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "zero while withdrawal pending"
        );
        assertEq(
            ark.assetsInWithdrawalQueue(),
            amount,
            "queue reflects escrowed value"
        );
    }
}
