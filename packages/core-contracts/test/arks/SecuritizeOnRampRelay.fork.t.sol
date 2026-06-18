// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test} from "forge-std/Test.sol";

interface IOnRamp {
    struct ExecutePreApprovedTransaction {
        string senderInvestor;
        address destination;
        bytes data;
        uint256 nonce;
    }

    function executePreApprovedTransaction(
        bytes memory signature,
        ExecutePreApprovedTransaction calldata txData
    ) external;

    function nonceByInvestor(
        string memory investorId
    ) external view returns (uint256);

    function custodianWallet() external view returns (address);
}

/**
 * @title SecuritizeOnRamp relay PoC (VBILL, Ethereum mainnet fork)
 * @notice Proves the production subscription path: a Securitize-signed `executePreApprovedTransaction`
 *         carrying an internal `subscribe(...)` mints the DSToken in a single transaction. Here we
 *         stand in for Securitize by signing with OUR key and granting that key the ISSUER role as
 *         the on-ramp sees it (`getRole(signer) -> ISSUER`). This is the exact mechanism the
 *         SecuritizeArk will RELAY once Securitize provides the signed payload off-chain (the Ark
 *         cannot self-sign in production — only an EXCHANGE/ISSUER key can).
 */
contract SecuritizeOnRampRelayForkTest is Test {
    address constant VBILL = 0x2255718832bC9fD3bE1CaF75084F4803DA14FF01;
    address constant ONRAMP = 0x488EFd3eD474b205A0AaDe3732E4741432cba50B;
    address constant TRUST = 0x08B9C1F3E2F236890b975dEe37eE3579A0d4516b;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint8 constant ISSUER_ROLE = 2;
    uint256 constant VBILL_MIN_SUBSCRIPTION = 50_000 * 1e6;

    bytes32 constant TXTYPE_HASH =
        keccak256(
            "ExecutePreApprovedTransaction(string senderInvestor,address destination,bytes data,uint256 nonce)"
        );
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    uint256 forkBlock = 25222568;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
    }

    function test_Fork_Relay_ExecutePreApprovedSubscribe() public {
        (address signer, uint256 pk) = makeAddrAndKey("securitizeSigner");
        address investor = makeAddr("summerArk"); // stands in for the Ark's wallet

        // Our signer "is" an ISSUER as far as the on-ramp's role check sees it.
        vm.mockCall(
            TRUST,
            abi.encodeWithSignature("getRole(address)", signer),
            abi.encode(uint256(ISSUER_ROLE))
        );

        // subscribe() pulls the liquidity token from the investor wallet -> fund it + approve.
        uint256 liquidity = VBILL_MIN_SUBSCRIPTION;
        deal(USDC, investor, liquidity);
        vm.prank(investor);
        IERC20(USDC).approve(ONRAMP, liquidity);

        string memory investorId = "summer-poc-1";
        bytes memory subscribeData = _buildSubscribeData(
            investorId,
            investor,
            liquidity
        );

        IOnRamp.ExecutePreApprovedTransaction memory txData = IOnRamp
            .ExecutePreApprovedTransaction({
                senderInvestor: investorId,
                destination: ONRAMP,
                data: subscribeData,
                nonce: IOnRamp(ONRAMP).nonceByInvestor(investorId)
            });

        bytes memory signature = _sign(pk, txData);

        address custodian = IOnRamp(ONRAMP).custodianWallet();
        uint256 custodianUsdcBefore = IERC20(USDC).balanceOf(custodian);

        // Anyone may relay the signed payload (the keeper, in production).
        IOnRamp(ONRAMP).executePreApprovedTransaction(signature, txData);

        // Fully synchronous: DSToken minted to the investor, USDC forwarded to the fund custodian.
        assertGt(
            IERC20(VBILL).balanceOf(investor),
            0,
            "DSToken minted in same tx"
        );
        assertEq(IERC20(USDC).balanceOf(investor), 0, "investor USDC pulled");
        assertGe(
            IERC20(USDC).balanceOf(custodian),
            custodianUsdcBefore,
            "USDC forwarded to fund custodian"
        );
    }

    function _buildSubscribeData(
        string memory investorId,
        address investor,
        uint256 liquidity
    ) internal view returns (bytes memory) {
        uint8[] memory attrIds = new uint8[](3);
        attrIds[0] = 1; // KYC_APPROVED
        attrIds[1] = 2; // ACCREDITED
        attrIds[2] = 4; // QUALIFIED
        uint256[] memory attrVals = new uint256[](3);
        attrVals[0] = 1;
        attrVals[1] = 1;
        attrVals[2] = 1;
        uint256[] memory attrExp = new uint256[](3);
        attrExp[0] = block.timestamp + 365 days;
        attrExp[1] = attrExp[0];
        attrExp[2] = attrExp[0];

        return
            abi.encodeWithSignature(
                "subscribe(string,address,string,uint8[],uint256[],uint256[],uint256,uint256,uint256,bytes32)",
                investorId,
                investor,
                "US",
                attrIds,
                attrVals,
                attrExp,
                uint256(0), // minOut
                liquidity, // liquidityAmount
                block.number + 1000, // blockLimit
                bytes32(0) // agreementHash
            );
    }

    function _sign(
        uint256 pk,
        IOnRamp.ExecutePreApprovedTransaction memory txData
    ) internal view returns (bytes memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256("SecuritizeOnRamp"),
                keccak256("1"),
                block.chainid,
                ONRAMP
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
        return abi.encodePacked(r, s, v);
    }
}
