// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SecuritizeArk.sol";
import {ISecuritizeArkErrors} from "../../src/errors/arks/ISecuritizeArkErrors.sol";
import {ISecuritizeOnRamp} from "../../src/interfaces/securitize/ISecuritizeOnRamp.sol";
import {ISecuritizeNavProvider} from "../../src/interfaces/securitize/ISecuritizeNavProvider.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title SecuritizeArk fork test — Securitize DSToken funds on Ethereum mainnet
 * @notice Validates SecuritizeArk against the REAL funds (VBILL, ACRED, STAC): on-chain registry +
 *         on-ramp resolution, decimals, the live NAV oracle (par + variable), NAV-source parity,
 *         payload validation, and a full SIGNED-RELAY deposit through the Ark (we stand in for
 *         Securitize by signing the on-ramp's EIP-712 payload with our own key, granted the ISSUER
 *         role as the on-ramp's role check sees it).
 */
contract SecuritizeArkForkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    struct Fund {
        string label;
        address token;
        address oracle;
        address registry;
        address onRamp;
        address trust;
        uint256 minAmount;
    }

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint8 constant ISSUER_ROLE = 2;
    uint256 constant RATE_TO_ORACLE_SCALE = 100; // navProvider 6-dec -> oracle 8-dec

    bytes32 constant TXTYPE_HASH =
        keccak256(
            "ExecutePreApprovedTransaction(string senderInvestor,address destination,bytes data,uint256 nonce)"
        );
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes4 constant SUBSCRIBE_SELECTOR = 0x3ca90bd4;

    Fund[3] public funds;
    SecuritizeArk[3] public arks;
    address public custodian;

    uint256 forkBlock = 25222568;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

        custodian = makeAddr("custodian");
        keeper = makeAddr("keeper");

        funds[0] = Fund(
            "VBILL",
            0x2255718832bC9fD3bE1CaF75084F4803DA14FF01,
            0xA569E68B5D110F2A255482c2997DFDBe1b2ab912,
            0x897e452425bd1c860d7F9bc14eA045cBbC0fA0d4,
            0x488EFd3eD474b205A0AaDe3732E4741432cba50B,
            0x08B9C1F3E2F236890b975dEe37eE3579A0d4516b,
            50_000 * 1e6
        );
        funds[1] = Fund(
            "ACRED",
            0x17418038ecF73BA4026c4f428547BF099706F27B,
            0xD6BcbbC87bFb6c8964dDc73DC3EaE6d08865d51C,
            0x3A8E9CD2E17E1F2904b7f745Da29C9cA765Cc319,
            0x368e7478fF8c88C9002c32E1F576fAbe2E9Ddf7B,
            0xc397436742eAF7C325DDBFc4dc63D95822b27101,
            1_000 * 1e6
        );
        funds[2] = Fund(
            "STAC",
            0x51C2d74017390CbBd30550179A16A1c28F7210fc,
            0xEdC6287D3D41b322AF600317628D7E226DD3add4,
            0x71080EB74E2816124327Af399aC8Cc518bbC7f49,
            0xc793b33120E5b74b601b00aF8FE2d30167CEB923,
            0xec0F580a0FE6eA53654537d34788AeBaD70A6370,
            1_000 * 1e6
        );

        for (uint256 i = 0; i < funds.length; i++) {
            arks[i] = _deployArk(funds[i]);
        }
    }

    function _deployArk(Fund memory f) internal returns (SecuritizeArk ark) {
        ArkParams memory params = ArkParams({
            name: string.concat("USDC Securitize ", f.label, " Ark"),
            details: "Securitize ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        ark = new SecuritizeArk(
            custodian,
            f.token,
            f.oracle,
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

    /* -------------------------- read-only wiring ------------------------- */

    function test_Fork_RegistryResolvedFromToken() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            assertEq(address(arks[i].registryService()), funds[i].registry);
        }
    }

    function test_Fork_Decimals() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            assertEq(arks[i].assetDecimals(), 6);
            assertEq(arks[i].shareDecimals(), 6);
            assertEq(arks[i].oracleDecimals(), 8);
            assertEq(IERC20Metadata(funds[i].token).decimals(), 6);
        }
    }

    function test_Fork_LiveNavValuation() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            SecuritizeArk ark = arks[i];
            (, int256 answer, , , ) = AggregatorV3Interface(funds[i].oracle)
                .latestRoundData();
            assertGt(answer, 0);
            uint256 expected = (uint256(answer) * (10 ** ark.assetDecimals())) /
                (10 ** ark.oracleDecimals());
            assertApproxEqAbs(
                ark.sharesToAssets(10 ** ark.shareDecimals()),
                expected,
                1
            );
        }
    }

    function test_Fork_OnRampResolved() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            ISecuritizeOnRamp ramp = arks[i].onRamp();
            assertEq(address(ramp), funds[i].onRamp);
            assertEq(ramp.liquidityToken(), USDC);
        }
    }

    function test_Fork_NavSourceParity() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            uint256 navRate = ISecuritizeNavProvider(
                arks[i].onRamp().navProvider()
            ).rate();
            (, int256 answer, , , ) = AggregatorV3Interface(funds[i].oracle)
                .latestRoundData();
            assertEq(navRate * RATE_TO_ORACLE_SCALE, uint256(answer));
        }
    }

    /* -------------------- payload validation (no signature) -------------- */

    function test_Fork_BoardRevertsOnWrongDestination() public {
        Fund memory f = funds[0];
        SecuritizeArk ark = arks[0];
        uint256 amount = f.minAmount;
        deal(USDC, commander, amount);
        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        // destination != the resolved on-ramp -> rejected before any relay
        vm.expectRevert(
            ISecuritizeArkErrors.InvalidSubscriptionPayload.selector
        );
        ark.board(amount, _payload(address(0xBEEF), address(ark), amount, 0));
        vm.stopPrank();
    }

    /* ----------------- end-to-end signed relay through the Ark ----------- */

    function test_Fork_E2E_RelayBoard() public {
        for (uint256 i = 0; i < funds.length; i++) {
            uint256 snap = vm.snapshotState();
            _e2eRelayBoard(funds[i], arks[i]);
            vm.revertToState(snap);
        }
    }

    function _e2eRelayBoard(Fund memory f, SecuritizeArk ark) internal {
        (address signer, uint256 pk) = makeAddrAndKey("securitizeSigner");
        // Stand in for Securitize: our signer "is" an ISSUER for the on-ramp's role check.
        vm.mockCall(
            f.trust,
            abi.encodeWithSignature("getRole(address)", signer),
            abi.encode(uint256(ISSUER_ROLE))
        );

        uint256 amount = f.minAmount;
        bytes memory data = _signedPayload(f, address(ark), amount, pk);

        address realCustodian = ISecuritizeOnRamp(f.onRamp).custodianWallet();
        uint256 custodianBefore = IERC20(USDC).balanceOf(realCustodian);

        deal(USDC, commander, amount);
        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, data);
        vm.stopPrank();

        assertGt(
            IERC20(f.token).balanceOf(address(ark)),
            0,
            string.concat(f.label, ": DSToken minted to ark")
        );
        assertTrue(ark.isArkOnboarded(), "subscription onboarded the ark");
        assertGe(
            IERC20(USDC).balanceOf(realCustodian),
            custodianBefore,
            "USDC forwarded toward fund custodian"
        );
        assertApproxEqRel(ark.totalAssets(), amount, 0.005e18);
    }

    /* ------------------------------ helpers ------------------------------ */

    function _subscribeData(
        address recipient,
        uint256 amount
    ) internal view returns (bytes memory) {
        uint8[] memory ids = new uint8[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 4;
        uint256[] memory vals = new uint256[](3);
        vals[0] = 1;
        vals[1] = 1;
        vals[2] = 1;
        uint256[] memory exp = new uint256[](3);
        exp[0] = block.timestamp + 365 days;
        exp[1] = exp[0];
        exp[2] = exp[0];
        return
            abi.encodeWithSelector(
                SUBSCRIBE_SELECTOR,
                "summer-fork-1",
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
    }

    /// @dev Payload with an EMPTY signature (for validation-revert tests that fail before relay).
    function _payload(
        address onRamp,
        address recipient,
        uint256 amount,
        uint256 nonce
    ) internal view returns (bytes memory) {
        ISecuritizeOnRamp.ExecutePreApprovedTransaction
            memory txData = ISecuritizeOnRamp.ExecutePreApprovedTransaction({
                senderInvestor: "summer-fork-1",
                destination: onRamp,
                data: _subscribeData(recipient, amount),
                nonce: nonce
            });
        return abi.encode(bytes(""), txData);
    }

    /// @dev Fully signed payload for the real on-ramp (EIP-712 over SecuritizeOnRamp/1).
    function _signedPayload(
        Fund memory f,
        address recipient,
        uint256 amount,
        uint256 pk
    ) internal view returns (bytes memory) {
        uint256 nonce = ISecuritizeOnRamp(f.onRamp).nonceByInvestor(
            "summer-fork-1"
        );
        ISecuritizeOnRamp.ExecutePreApprovedTransaction
            memory txData = ISecuritizeOnRamp.ExecutePreApprovedTransaction({
                senderInvestor: "summer-fork-1",
                destination: f.onRamp,
                data: _subscribeData(recipient, amount),
                nonce: nonce
            });

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("SecuritizeOnRamp"),
                keccak256("1"),
                block.chainid,
                f.onRamp
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                TXTYPE_HASH,
                keccak256(bytes(txData.senderInvestor)),
                txData.destination,
                keccak256(txData.data),
                txData.nonce
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encode(abi.encodePacked(r, s, v), txData);
    }
}
