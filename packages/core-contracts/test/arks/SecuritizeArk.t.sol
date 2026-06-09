// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/SecuritizeArk.sol";
import {ISecuritizeArkErrors} from "../../src/errors/arks/ISecuritizeArkErrors.sol";
import {ISecuritizeOnRamp} from "../../src/interfaces/securitize/ISecuritizeOnRamp.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

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

    function isWallet(address a) external view returns (bool) {
        return registered[a];
    }

    function getInvestor(address a) external view returns (string memory) {
        return investorOf[a];
    }
}

/// @notice Minimal Securitize DSToken: compliance-gated ERC20. Mint (issuance) is ungated;
///         genuine transfers require both parties registered and the token unpaused.
contract MockDSToken is ERC20 {
    uint8 private immutable _dec;
    MockRegistry public registry;
    bool public paused;
    bool public registryUnset;
    address public onRampAddr; // returned for getDSService(16384)

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

    function getDSService(uint256 id) external view returns (address) {
        if (id == 4 && !registryUnset) return address(registry);
        if (id == 16384) return onRampAddr;
        return address(0);
    }

    function setRegistryUnset(bool v) external {
        registryUnset = v;
    }

    function setOnRamp(address a) external {
        onRampAddr = a;
    }

    function setPaused(bool v) external {
        paused = v;
    }

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
        if (from != address(0) && to != address(0)) {
            require(!paused, "Token paused");
            require(registry.isWallet(from), "Wallet not in registry service");
            require(registry.isWallet(to), "Wallet not in registry service");
        }
        super._update(from, to, value);
    }
}

/// @notice Chainlink-compatible mock oracle (matches the RedStone push feed the funds use).
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
        return "Mock NAV";
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

/// @notice Minimal Securitize on-ramp: relays a pre-approved subscription. Decodes the inner
///         subscribe, onboards + pulls liquidity from the investor wallet, mints DSToken at `rate`.
///         The signature is ignored (role check is exercised against the real contract on a fork).
contract MockOnRamp {
    MockDSToken public token;
    MockRegistry public registry;
    IERC20 public liquidity;
    address public liquidityToken;
    address public custodian;
    uint256 public rate; // NAV in asset decimals (6), e.g. 1e6 = $1.00
    uint256 public fee;

    struct ExecutePreApprovedTransaction {
        string senderInvestor;
        address destination;
        bytes data;
        uint256 nonce;
    }

    constructor(
        MockDSToken _token,
        MockRegistry _registry,
        IERC20 _liquidity,
        address _custodian,
        uint256 _rate
    ) {
        token = _token;
        registry = _registry;
        liquidity = _liquidity;
        liquidityToken = address(_liquidity);
        custodian = _custodian;
        rate = _rate;
    }

    function setLiquidityToken(address a) external {
        liquidityToken = a;
    }

    function setRate(uint256 v) external {
        rate = v;
    }

    function setFee(uint256 v) external {
        fee = v;
    }

    function custodianWallet() external view returns (address) {
        return custodian;
    }

    function navProvider() external view returns (address) {
        return address(this);
    }

    function nonceByInvestor(string calldata) external pure returns (uint256) {
        return 0;
    }

    function executePreApprovedTransaction(
        bytes calldata,
        ExecutePreApprovedTransaction calldata txData
    ) external {
        bytes memory args = new bytes(txData.data.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = txData.data[i + 4];
        }
        (, address investorWallet, , , , , , uint256 liquidityAmount, , ) = abi
            .decode(
                args,
                (
                    string,
                    address,
                    string,
                    uint8[],
                    uint256[],
                    uint256[],
                    uint256,
                    uint256,
                    uint256,
                    bytes32
                )
            );
        registry.register(investorWallet, "onramp-investor");
        liquidity.transferFrom(investorWallet, custodian, liquidityAmount);
        uint256 out = ((liquidityAmount - fee) * 1e6) / rate;
        token.issue(investorWallet, out);
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
    MockOnRamp public onRampMock;
    ArkParams public params;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public custodian;

    uint8 internal constant ORACLE_DECIMALS = 8;
    uint256 internal constant ORACLE_SCALE = 1e8;
    uint256 internal constant ORACLE_TO_RATE_SCALE = 100;
    int256 internal constant PAR_NAV = 1e8; // $1.00 at 8 decimals
    int256 internal constant VARIABLE_NAV = 109796093000; // ~$1097.96 (ACRED-like)
    bytes4 internal constant SUBSCRIBE_SELECTOR = 0x3ca90bd4;

    uint256 forkBlock = 21666256;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

        usdc = IERC20(USDC_ADDRESS);
        custodian = makeAddr("custodian");
        keeper = makeAddr("keeper");

        registry = new MockRegistry();
        vbill = new MockDSToken(registry, 6);
        oracle = new MockOracle(ORACLE_DECIMALS, PAR_NAV);
        onRampMock = new MockOnRamp(vbill, registry, usdc, custodian, 1e6);
        vbill.setOnRamp(address(onRampMock));

        params = ArkParams({
            name: "USDC Securitize VBILL Ark",
            details: "USDC Securitize VBILL Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = _deployArk();
        vm.stopPrank();

        ArkParams memory bParams = params;
        bParams.name = "BufferArk";
        bParams.requiresKeeperData = false;
        bufferArk = new BufferArk(bParams, address(commander));

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();
    }

    function _deployArk() internal returns (SecuritizeArk) {
        return
            new SecuritizeArk(
                custodian,
                address(vbill),
                address(oracle),
                Percentage.wrap(PERCENTAGE_FACTOR / 2),
                Percentage.wrap(PERCENTAGE_FACTOR / 2),
                params
            );
    }

    /* ------------------------------ helpers ------------------------------ */

    /// @dev Builds the keeper board payload: a (signature, txData) where txData.data is a
    ///      subscribe(...) minting `amount` worth of DSToken to `recipient`.
    function _payload(
        address onRamp,
        address recipient,
        uint256 amount
    ) internal view returns (bytes memory) {
        return _payloadWith(onRamp, SUBSCRIBE_SELECTOR, recipient, amount);
    }

    function _payloadWith(
        address onRamp,
        bytes4 selector,
        address recipient,
        uint256 amount
    ) internal view returns (bytes memory) {
        uint8[] memory ids = new uint8[](0);
        uint256[] memory vals = new uint256[](0);
        uint256[] memory exp = new uint256[](0);
        bytes memory inner = abi.encodeWithSelector(
            selector,
            "investor-1",
            recipient,
            "US",
            ids,
            vals,
            exp,
            uint256(0),
            amount,
            block.number + 1000,
            bytes32(0)
        );
        ISecuritizeOnRamp.ExecutePreApprovedTransaction
            memory txData = ISecuritizeOnRamp.ExecutePreApprovedTransaction({
                senderInvestor: "investor-1",
                destination: onRamp,
                data: inner,
                nonce: 0
            });
        return abi.encode(bytes(""), txData);
    }

    function _board(uint256 amount) internal {
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, _payload(address(onRampMock), address(ark), amount));
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

    function test_Constructor_ResolvesRegistryFromToken() public view {
        assertEq(address(ark.registryService()), address(registry));
        assertEq(ark.custodianWallet(), custodian);
        assertEq(address(ark.asset()), USDC_ADDRESS);
        assertEq(address(ark.onRamp()), address(onRampMock));
    }

    function test_Constructor_RevertsWithoutKeeperData() public {
        params.requiresKeeperData = false;
        vm.expectRevert(ISecuritizeArkErrors.MustRequireKeeperData.selector);
        _deployArk();
        params.requiresKeeperData = true;
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

    /* --------------------------- deposit (relay) ------------------------- */

    function test_Board_RelaySynchronous() public {
        uint256 amount = 1000 * 1e6;
        uint256 custBefore = usdc.balanceOf(custodian);

        _board(amount);

        assertEq(
            usdc.balanceOf(custodian),
            custBefore + amount,
            "USDC -> custodian"
        );
        assertEq(vbill.balanceOf(address(ark)), 1000 * 1e6, "minted same tx");
        assertEq(ark.totalAssets(), amount, "valued immediately");
        assertTrue(ark.isArkOnboarded(), "onboarded by the subscription");
    }

    function test_Board_VariableNav() public {
        oracle.setAnswer(VARIABLE_NAV);
        onRampMock.setRate(uint256(VARIABLE_NAV) / ORACLE_TO_RATE_SCALE);

        uint256 shares = 10 * 1e6;
        uint256 amount = (uint256(VARIABLE_NAV) * shares) / ORACLE_SCALE;
        _board(amount);

        assertApproxEqAbs(
            vbill.balanceOf(address(ark)),
            shares,
            1,
            "minted at NAV"
        );
        assertApproxEqAbs(ark.totalAssets(), amount, 2, "valued at NAV");
    }

    function test_Board_RevertsWrongDestination() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        // destination != resolved on-ramp
        vm.expectRevert(
            ISecuritizeArkErrors.InvalidSubscriptionPayload.selector
        );
        ark.board(amount, _payload(address(0xBEEF), address(ark), amount));
        vm.stopPrank();
    }

    function test_Board_RevertsWrongRecipient() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        // mints to someone other than the Ark
        vm.expectRevert(
            ISecuritizeArkErrors.InvalidSubscriptionPayload.selector
        );
        ark.board(
            amount,
            _payload(address(onRampMock), address(0xBEEF), amount)
        );
        vm.stopPrank();
    }

    function test_Board_RevertsWrongAmount() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        // payload's liquidityAmount != boarded amount
        vm.expectRevert(
            ISecuritizeArkErrors.InvalidSubscriptionPayload.selector
        );
        ark.board(
            amount,
            _payload(address(onRampMock), address(ark), amount + 1)
        );
        vm.stopPrank();
    }

    function test_Board_RevertsWrongSelector() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(
            ISecuritizeArkErrors.InvalidSubscriptionPayload.selector
        );
        ark.board(
            amount,
            _payloadWith(
                address(onRampMock),
                bytes4(0xdeadbeef),
                address(ark),
                amount
            )
        );
        vm.stopPrank();
    }

    function test_Board_RevertsWhenOnRampNotConfigured() public {
        vbill.setOnRamp(address(0));
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(ISecuritizeArkErrors.OnRampNotConfigured.selector);
        ark.board(amount, _payload(address(onRampMock), address(ark), amount));
        vm.stopPrank();
    }

    function test_Board_RevertsLiquidityTokenMismatch() public {
        onRampMock.setLiquidityToken(address(0xBEEF));
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecuritizeArkErrors.OnRampAssetMismatch.selector,
                USDC_ADDRESS,
                address(0xBEEF)
            )
        );
        ark.board(amount, _payload(address(onRampMock), address(ark), amount));
        vm.stopPrank();
    }

    function test_Board_RevertsSharesBelowSlippage() public {
        // Securitize NAV 1% above our oracle => mints ~1% fewer shares than minShares (0.5%).
        onRampMock.setRate(1.01e6);
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(); // SharesNotArrived(expected, received)
        ark.board(amount, _payload(address(onRampMock), address(ark), amount));
        vm.stopPrank();
    }

    function test_Board_RevertsWhenFrozen() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(ISecuritizeArkErrors.ArkIsFrozen.selector);
        ark.board(amount, _payload(address(onRampMock), address(ark), amount));
        vm.stopPrank();
    }

    /* --------------------------- withdrawal ------------------------------ */

    function test_RequestWithdrawal_And_Sweep() public {
        uint256 amount = 1000 * 1e6;
        _board(amount);
        registry.register(custodian, "custodian-investor");

        vm.prank(keeper);
        ark.requestWithdrawal(amount);
        assertEq(vbill.balanceOf(custodian), 1000 * 1e6, "shares to custodian");
        assertEq(ark.pendingWithdrawalShares(), 1000 * 1e6);

        deal(USDC_ADDRESS, address(ark), amount);
        _mockCommanderBuffer();
        vm.prank(keeper);
        ark.sweep();

        assertEq(ark.pendingWithdrawalShares(), 0);
        assertEq(usdc.balanceOf(address(bufferArk)), amount);
        assertEq(ark.totalAssets(), 0);
    }

    function test_RequestWithdrawal_RevertsIfCustodianNotCompliant() public {
        uint256 amount = 1000 * 1e6;
        _board(amount); // onboards the ark, not the custodian
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

    function test_RequestWithdrawal_RevertsIfDoubleRequested() public {
        uint256 amount = 1000 * 1e6;
        _board(amount);
        registry.register(custodian, "custodian-investor");
        vm.startPrank(keeper);
        ark.requestWithdrawal(amount / 2);
        vm.expectRevert(ISecuritizeArkErrors.PendingWithdrawalActive.selector);
        ark.requestWithdrawal(amount / 2);
        vm.stopPrank();
    }

    function test_WithdrawableTotalAssets_AlwaysZero() public {
        assertEq(ark.withdrawableTotalAssets(), 0);
        uint256 amount = 1000 * 1e6;
        _board(amount);
        assertEq(ark.withdrawableTotalAssets(), 0, "zero while holding shares");
        registry.register(custodian, "custodian-investor");
        vm.prank(keeper);
        ark.requestWithdrawal(amount);
        assertEq(ark.withdrawableTotalAssets(), 0, "zero while pending");
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }

    /* --------------------------- access / views -------------------------- */

    function test_AccessControl() public {
        address rando = makeAddr("rando");
        vm.startPrank(rando);
        vm.expectRevert();
        ark.requestWithdrawal(1e6);
        vm.expectRevert();
        ark.sweep();
        vm.expectRevert();
        ark.setCustodianWallet(rando);
        vm.expectRevert();
        ark.setArkFrozen(true, 0);
        vm.expectRevert();
        ark.emergencySweep();
        vm.stopPrank();
    }

    function test_AsyncNoOpsAndViews() public {
        vm.startPrank(keeper);
        ark.claimWithdrawal();
        ark.withdrawUsingSwap(1e6, new bytes(0));
        vm.stopPrank();
        assertEq(ark.withdrawalRequestId(), 0);
        assertFalse(ark.isWithdrawalClaimRequired());
        assertEq(ark.assetsInWithdrawalQueue(), 0);
    }

    /* ----------------------------- oracle -------------------------------- */

    function test_RevertIfOraclePriceNotPositive() public {
        oracle.setAnswer(0);
        vm.expectRevert(ISecuritizeArkErrors.OraclePriceNotPositive.selector);
        ark.sharesToAssets(1e6);
    }

    function test_RevertIfOracleStale() public {
        oracle.setRoundData(1, PAR_NAV, block.timestamp - 48 hours - 1, 1);
        vm.expectRevert(ISecuritizeArkErrors.StaleOraclePrice.selector);
        ark.sharesToAssets(1e6);
    }

    function test_ParValuation() public view {
        assertEq(ark.sharesToAssets(1e6), 1e6);
        assertEq(ark.sharesToAssets(1000 * 1e6), 1000 * 1e6);
    }

    /* --------------------- review fixes (#1,#2,#4,#5) -------------------- */

    /// @notice #1: the keeper must NOT be able to redirect redemption shares; only governor.
    function test_SetCustodianWallet_GovernorOnly() public {
        address newCustodian = makeAddr("newCustodian");
        vm.prank(keeper);
        vm.expectRevert();
        ark.setCustodianWallet(newCustodian);

        vm.prank(governor);
        ark.setCustodianWallet(newCustodian);
        assertEq(ark.custodianWallet(), newCustodian);
    }

    /// @notice #2: disembark/move with a nonzero amount is disabled (exit only via sweep).
    function test_Disembark_RevertsForNonzero() public {
        vm.startPrank(commander);
        vm.expectRevert(ISecuritizeArkErrors.DisembarkDisabled.selector);
        ark.disembark(1, abi.encode(uint256(1))); // requiresKeeperData -> non-empty data
        vm.stopPrank();
    }

    /// @notice #4: a NAV rise between request and settlement must NOT brick the sweep, since the
    ///         floor is the asset value snapshotted at request time (not a live-NAV reconversion).
    function test_Sweep_NavRiseDoesNotBrick() public {
        uint256 amount = 1000 * 1e6;
        _board(amount);
        registry.register(custodian, "custodian-investor");
        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        // NAV climbs 10% after the request; previously this reverted the sweep.
        oracle.setAnswer((PAR_NAV * 110) / 100);

        deal(USDC_ADDRESS, address(ark), amount); // Securitize returns the requested asset value
        _mockCommanderBuffer();
        vm.prank(keeper);
        ark.sweep();

        assertEq(usdc.balanceOf(address(bufferArk)), amount);
        assertEq(ark.pendingWithdrawalShares(), 0);
        assertEq(ark.pendingWithdrawalAssets(), 0);
    }

    function test_Sweep_RevertsBelowSnapshotFloor() public {
        uint256 amount = 1000 * 1e6;
        _board(amount);
        registry.register(custodian, "custodian-investor");
        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        // Return less than amount - 0.5% sweepSlippage.
        deal(USDC_ADDRESS, address(ark), (amount * 99) / 100); // 1% short
        _mockCommanderBuffer();
        vm.prank(keeper);
        vm.expectRevert(); // InsufficientAssetsReturned
        ark.sweep();
    }

    /// @notice #5: an on-ramp fee above depositSlippage bricks deposits until the governor sets a
    ///         separate fee tolerance; then it succeeds.
    function test_OnRampFeeTolerance() public {
        uint256 amount = 1000 * 1e6;
        onRampMock.setFee(10 * 1e6); // 1% fee, above the 0.5% depositSlippage

        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(); // SharesNotArrived (fee not yet tolerated)
        ark.board(amount, _payload(address(onRampMock), address(ark), amount));
        vm.stopPrank();

        // keeper cannot set it; governor can
        vm.prank(keeper);
        vm.expectRevert();
        ark.setSubscriptionFeeTolerance(Percentage.wrap(PERCENTAGE_FACTOR));
        vm.prank(governor);
        ark.setSubscriptionFeeTolerance(Percentage.wrap(PERCENTAGE_FACTOR)); // 1%

        _board(amount); // now succeeds
        assertEq(
            vbill.balanceOf(address(ark)),
            990 * 1e6,
            "minted net of 1% fee"
        );
    }

    function test_SetSubscriptionFeeTolerance_RevertsAboveMax() public {
        vm.prank(governor);
        vm.expectRevert();
        ark.setSubscriptionFeeTolerance(
            Percentage.wrap(PERCENTAGE_FACTOR * 6) // 6% > 5% max
        );
    }
}
