// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {IAdmiralsQuartersEvents} from "../../src/events/IAdmiralsQuartersEvents.sol";
import {IDistributor} from "../../src/interfaces/merkl/IDistributor.sol";
import {ISignatureTransfer} from "../../src/interfaces/permit2/IPermit2.sol";
import {AdmiralsQuartersWhitelistTest} from "./AdmiralsQuartersWhitelist.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConfigurationManaged} from "@summerfi/config-contracts/contracts/ConfigurationManaged.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";

contract AdmiralsQuartersWhitelistPermitTest is AdmiralsQuartersWhitelistTest {
    uint256 internal ownerPrivateKey;
    address internal owner;
    address internal solver;

    // Permit2 address on mainnet
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function setUp() public override {
        super.setUp();

        // Setup owner with private key for signing
        ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);
        solver = address(0x1337);

        // Give owner some USDC
        deal(USDC_ADDRESS, owner, 10000e6);

        // Setup DAI
        deal(DAI_ADDRESS, owner, 10000e18);

        vm.label(owner, "Owner");
        vm.label(solver, "Solver");

        // Set up the access control for the solver to be able to execute multicall if needed. 
        // Wait, AdmiralsQuartersWhitelist does not require solver to be whitelisted for multicall,
        // it requires the `owner` to be whitelisted for `fleetCommander` context.

        // Add owner to whitelist for usdcFleet
        _setWhitelisted(address(usdcFleet), owner, true);


    }

    function test_enterFleetWithPermit2() public {
        uint256 amount = 1000e6;
        uint256 deadline = block.timestamp + 100;

        // First step: User must approve Permit2 (done once usually)
        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        // Second step: User signs Permit2 transfer
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 0,
                deadline: deadline
            });

        bytes memory signature = _getPermit2Signature(
            permit,
            address(admiralsQuarters),
            ownerPrivateKey
        );

        // Third step: Execute enterFleetWithPermit2 as the intent solver
        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (
                owner,
                address(usdcFleet),
                amount,
                owner, // receiver
                permit,
                signature
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IAdmiralsQuartersEvents.FleetEntered(
            owner,
            address(usdcFleet),
            amount,
            amount // assuming 1:1 shares
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        uint256 shares = usdcFleet.balanceOf(owner);
        uint256 depositedAssets = usdcFleet.convertToAssets(shares);
        assertApproxEqAbs(
            depositedAssets,
            amount,
            2,
            "Shares should convert to approx deposited amount"
        );

        assertEq(shares, usdcFleet.previewDeposit(amount));
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have 0 balance"
        );
    }

    // Helper to get USDC nonce
    function _getUSDCNonce(
        address token,
        address user
    ) internal view returns (uint256) {
        (, bytes memory returnData) = token.staticcall(
            abi.encodeWithSignature("nonces(address)", user)
        );
        return abi.decode(returnData, (uint256));
    }

    // Helper to get USDC digest
    function _getUSDCDigest(
        address token,
        bytes32 structHash
    ) internal view returns (bytes32) {
        (, bytes memory returnData) = token.staticcall(
            abi.encodeWithSignature("DOMAIN_SEPARATOR()")
        );
        bytes32 domainSeparator = abi.decode(returnData, (bytes32));
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
    }

    // Helper to sign Permit2
    function _getPermit2Signature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 TOKEN_PERMISSIONS_TYPEHASH = keccak256(
            "TokenPermissions(address token,uint256 amount)"
        );
        bytes32 PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

        bytes32 domainSeparator = ISignatureTransfer(PERMIT2)
            .DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TRANSFER_FROM_TYPEHASH,
                keccak256(
                    abi.encode(
                        TOKEN_PERMISSIONS_TYPEHASH,
                        permit.permitted.token,
                        permit.permitted.amount
                    )
                ),
                spender,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
