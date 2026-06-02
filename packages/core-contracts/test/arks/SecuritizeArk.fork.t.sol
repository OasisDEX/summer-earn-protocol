// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/SecuritizeArk.sol";
import {ISecuritizeArkErrors} from "../../src/errors/arks/ISecuritizeArkErrors.sol";
import {ISecuritizeNavProvider} from "../../src/interfaces/securitize/ISecuritizeNavProvider.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test} from "forge-std/Test.sol";

/// @dev Admin surface of the Securitize RegistryService used ONLY by this test to onboard
///      wallets on a fork. `updateInvestor` is `onlyIssuerOrTransferAgentOrAbove`; we impersonate
///      the fund's on-ramp contract, which holds the ISSUER role on the trust service (verified
///      live: trustService.getRole(onRamp) == 2 for all three funds).
interface IRegistryAdmin {
    function updateInvestor(
        string calldata _id,
        string calldata _collisionHash,
        string memory _country,
        address[] memory _wallets,
        uint8[] memory _attributeIds,
        uint256[] memory _attributeValues,
        uint256[] memory _attributeExpirations
    ) external returns (bool);
}

/**
 * @title SecuritizeArk fork test — Securitize DSToken funds on Ethereum mainnet
 * @notice Validates SecuritizeArk against the REAL Securitize funds we integrate (VBILL, ACRED,
 *         STAC), their DSToken registries, and their live RedStone NAV feeds. Covers a $1.00-par
 *         fund (VBILL) and two variable-NAV funds (ACRED ~ $1097, STAC ~ $1019), proving the
 *         generic oracle path values all of them correctly.
 *
 *         The full board -> clear -> withdraw -> sweep cycle requires the Ark + custodian to be
 *         onboarded as investor wallets by Securitize (an `onlyExchangeOrAbove` operation we cannot
 *         reproduce on a fork without the privileged key); that cycle is covered by the mock-based
 *         unit tests in SecuritizeArk.t.sol. Here we assert the real integration points: on-chain
 *         registry resolution, the live NAV oracle (par + variable), decimals, and that the real
 *         registry gate blocks an un-onboarded Ark.
 */
contract SecuritizeArkForkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    struct Fund {
        string label;
        address token;
        address oracle;
        address registry;
        address onRamp;
    }

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Ethereum mainnet (verified 2026-06-01).
    Fund[3] public funds;
    SecuritizeArk[3] public arks;
    address public custodian;

    // Block whose timestamp (1780317443) keeps all three RedStone feeds within the 24h heartbeat.
    uint256 forkBlock = 25222568;

    function setUp() public {
        // Fork must be selected BEFORE initializeCoreContracts() so the core contracts are
        // deployed on the active fork (ark-development skill: fork-test setup order).
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        initializeCoreContracts();

        custodian = makeAddr("custodian");
        keeper = makeAddr("keeper");

        funds[0] = Fund({
            label: "VBILL",
            token: 0x2255718832bC9fD3bE1CaF75084F4803DA14FF01,
            oracle: 0xA569E68B5D110F2A255482c2997DFDBe1b2ab912,
            registry: 0x897e452425bd1c860d7F9bc14eA045cBbC0fA0d4,
            onRamp: 0x488EFd3eD474b205A0AaDe3732E4741432cba50B
        });
        funds[1] = Fund({
            label: "ACRED",
            token: 0x17418038ecF73BA4026c4f428547BF099706F27B,
            oracle: 0xD6BcbbC87bFb6c8964dDc73DC3EaE6d08865d51C,
            registry: 0x3A8E9CD2E17E1F2904b7f745Da29C9cA765Cc319,
            onRamp: 0x368e7478fF8c88C9002c32E1F576fAbe2E9Ddf7B
        });
        funds[2] = Fund({
            label: "STAC",
            token: 0x51C2d74017390CbBd30550179A16A1c28F7210fc,
            oracle: 0xEdC6287D3D41b322AF600317628D7E226DD3add4,
            registry: 0x71080EB74E2816124327Af399aC8Cc518bbC7f49,
            onRamp: 0xc793b33120E5b74b601b00aF8FE2d30167CEB923
        });

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
            requiresKeeperData: false,
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

    function test_Fork_RegistryResolvedFromToken() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            assertEq(
                address(arks[i].registryService()),
                funds[i].registry,
                string.concat(funds[i].label, ": registry from getDSService(4)")
            );
        }
    }

    function test_Fork_Decimals() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            assertEq(arks[i].assetDecimals(), 6, "USDC decimals");
            assertEq(arks[i].shareDecimals(), 6, "DSToken decimals");
            assertEq(arks[i].oracleDecimals(), 8, "RedStone feed decimals");
            assertEq(IERC20Metadata(funds[i].token).decimals(), 6);
        }
    }

    /// @notice Values 1 share off the live NAV feed — works for par (VBILL) and variable-NAV
    ///         (ACRED, STAC) funds alike.
    function test_Fork_LiveNavValuation() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            SecuritizeArk ark = arks[i];
            (, int256 answer, , , ) = AggregatorV3Interface(funds[i].oracle)
                .latestRoundData();
            assertGt(answer, 0, "live NAV positive");

            uint256 oneShare = 10 ** ark.shareDecimals();
            uint256 expected = (uint256(answer) * (10 ** ark.assetDecimals())) /
                (10 ** ark.oracleDecimals());
            assertApproxEqAbs(
                ark.sharesToAssets(oneShare),
                expected,
                1,
                string.concat(funds[i].label, ": 1 share == live NAV in USDC")
            );
        }
    }

    function test_Fork_ArkNotOnboarded() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            assertFalse(arks[i].isArkOnboarded(), "fresh ark not onboarded");
        }
    }

    function test_Fork_BoardRevertsAgainstRealRegistry() public {
        for (uint256 i = 0; i < funds.length; i++) {
            SecuritizeArk ark = arks[i];
            uint256 amount = 1000 * 1e6;
            deal(USDC, commander, amount);
            vm.startPrank(commander);
            IERC20(USDC).approve(address(ark), amount);
            vm.expectRevert(ISecuritizeArkErrors.ArkNotRegistered.selector);
            ark.board(amount, bytes(""));
            vm.stopPrank();
        }
    }

    function test_Fork_ConstructorWiring() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            assertEq(arks[i].custodianWallet(), custodian);
            assertEq(address(arks[i].asset()), USDC);
            assertEq(address(arks[i].shareToken()), funds[i].token);
            assertEq(address(arks[i].oracle()), funds[i].oracle);
            assertTrue(arks[i].useOnRampSubscription(), "on-ramp path default");
        }
    }

    /// @notice The on-ramp (subscription/swap contract) resolves from the token's service
    ///         registry (id 16384) and currently accepts investor-initiated swaps.
    function test_Fork_OnRampResolvedAndLive() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            ISecuritizeOnRamp ramp = arks[i].onRamp();
            assertEq(
                address(ramp),
                funds[i].onRamp,
                string.concat(
                    funds[i].label,
                    ": onRamp from getDSService(16384)"
                )
            );
            assertEq(ramp.liquidityToken(), USDC, "USDC-denominated on-ramp");
            assertTrue(
                ramp.investorSubscriptionEnabled(),
                "swap subscriptions live"
            );
        }
    }

    /// @notice Cross-checks the two on-chain NAV sources: Securitize's navProvider (6 dec,
    ///         operator-set TSSO root) vs the RedStone feed the Ark prices with (8 dec). They
    ///         publish the same upstream value.
    function test_Fork_NavSourceParity() public view {
        for (uint256 i = 0; i < funds.length; i++) {
            uint256 navRate = ISecuritizeNavProvider(
                arks[i].onRamp().navProvider()
            ).rate();
            (, int256 answer, , , ) = AggregatorV3Interface(funds[i].oracle)
                .latestRoundData();
            assertEq(
                navRate * 100, // 6 dec -> 8 dec
                uint256(answer),
                string.concat(funds[i].label, ": navProvider == RedStone feed")
            );
        }
    }

    /* ------------------- end-to-end with real onboarding ----------------- */

    /// @dev Onboards `wallet` as a KYC'd/accredited investor wallet in the fund's REAL registry
    ///      by impersonating the fund's on-ramp (ISSUER role) — the fork equivalent of
    ///      Securitize's off-chain onboarding (mirrors the SyrupArkV2 authority-impersonation
    ///      pattern).
    function _onboardWalletOnFork(
        Fund memory f,
        address wallet,
        string memory investorId
    ) internal {
        uint8[] memory attrIds = new uint8[](3);
        attrIds[0] = 1; // KYC_APPROVED
        attrIds[1] = 2; // ACCREDITED
        attrIds[2] = 4; // QUALIFIED
        uint256[] memory attrVals = new uint256[](3);
        attrVals[0] = 1; // APPROVED
        attrVals[1] = 1;
        attrVals[2] = 1;
        uint256[] memory attrExp = new uint256[](3);
        attrExp[0] = block.timestamp + 365 days;
        attrExp[1] = block.timestamp + 365 days;
        attrExp[2] = block.timestamp + 365 days;
        address[] memory wallets = new address[](1);
        wallets[0] = wallet;

        vm.prank(f.onRamp); // holds ISSUER on the fund's trust service
        IRegistryAdmin(f.registry).updateInvestor(
            investorId,
            "",
            "US",
            wallets,
            attrIds,
            attrVals,
            attrExp
        );
    }

    /// @notice REAL end-to-end subscription: onboard the Ark in the live registry, then board
    ///         through the live on-ramp — USDC flows to the real fund custodian and freshly
    ///         minted DSTokens arrive at the Ark in the same transaction.
    function test_Fork_E2E_BoardViaLiveOnRamp() public {
        for (uint256 i = 0; i < funds.length; i++) {
            SecuritizeArk ark = arks[i];
            _onboardWalletOnFork(
                funds[i],
                address(ark),
                string.concat("SUMMER_ARK_", funds[i].label)
            );
            assertTrue(ark.isArkOnboarded(), "ark onboarded in real registry");

            ISecuritizeOnRamp ramp = ark.onRamp();
            uint256 amount = ramp.minSubscriptionAmount();
            if (amount < 1000 * 1e6) amount = 1000 * 1e6;

            address realCustodian = ramp.custodianWallet();
            uint256 custodianBefore = IERC20(USDC).balanceOf(realCustodian);

            deal(USDC, commander, amount);
            vm.startPrank(commander);
            IERC20(USDC).approve(address(ark), amount);
            ark.board(amount, bytes(""));
            vm.stopPrank();

            // Synchronous: no pending bookkeeping, tokens minted, USDC at the REAL custodian.
            assertEq(ark.pendingDepositAssets(), 0, "no pending deposit");
            uint256 shares = IERC20(funds[i].token).balanceOf(address(ark));
            assertGt(shares, 0, "DSTokens minted same tx");
            assertGe(
                IERC20(USDC).balanceOf(realCustodian),
                custodianBefore,
                "USDC forwarded toward fund custodian"
            );
            // Valued within depositSlippage (0.5%) of the boarded amount.
            assertApproxEqRel(
                ark.totalAssets(),
                amount,
                0.005e18,
                string.concat(funds[i].label, ": totalAssets ~= subscription")
            );
        }
    }

    /// @notice After a live subscription, the async exit leg: transfer the DSTokens to a
    ///         (registry-onboarded) custodian via requestWithdrawal, then sweep returned USDC.
    function test_Fork_E2E_WithdrawalLegAfterLiveBoard() public {
        for (uint256 i = 0; i < funds.length; i++) {
            // Each fund warps time (lock-up) independently; snapshot/revert keeps the others at
            // the original fork timestamp so their live oracles stay fresh.
            uint256 snap = vm.snapshotState();
            SecuritizeArk ark = arks[i];
            _onboardWalletOnFork(
                funds[i],
                address(ark),
                string.concat("SUMMER_ARK_", funds[i].label)
            );
            // Our withdrawal custodian must also be a registered investor wallet.
            _onboardWalletOnFork(
                funds[i],
                custodian,
                string.concat("SUMMER_CUSTODIAN_", funds[i].label)
            );

            ISecuritizeOnRamp ramp = ark.onRamp();
            uint256 amount = ramp.minSubscriptionAmount();
            if (amount < 1000 * 1e6) amount = 1000 * 1e6;
            deal(USDC, commander, amount);
            vm.startPrank(commander);
            IERC20(USDC).approve(address(ark), amount);
            ark.board(amount, bytes(""));
            vm.stopPrank();

            uint256 value = ark.totalAssets();

            // Newly issued DSTokens carry a US/non-US lock-up (VBILL 3d, STAC 1d). Warp past it,
            // then refresh the RedStone feed's `updatedAt` so it stays within the heartbeat.
            (, int256 answer, , , ) = AggregatorV3Interface(funds[i].oracle)
                .latestRoundData();
            vm.warp(block.timestamp + 3 days + 1);
            vm.mockCall(
                funds[i].oracle,
                abi.encodeWithSelector(
                    AggregatorV3Interface.latestRoundData.selector
                ),
                abi.encode(
                    uint80(1),
                    answer,
                    block.timestamp,
                    block.timestamp,
                    uint80(1)
                )
            );

            vm.prank(keeper);
            ark.requestWithdrawal(value);

            // Essentially all DSTokens sent; allow sub-wei dust from NAV asset<->share rounding.
            assertLe(
                IERC20(funds[i].token).balanceOf(address(ark)),
                2,
                "DSTokens sent for redemption (dust tolerance)"
            );
            assertGt(
                IERC20(funds[i].token).balanceOf(custodian),
                0,
                "custodian received DSTokens"
            );
            assertApproxEqRel(
                ark.assetsInWithdrawalQueue(),
                value,
                0.005e18,
                "queue tracks escrowed value"
            );
            vm.revertToState(snap);
        }
    }
}
