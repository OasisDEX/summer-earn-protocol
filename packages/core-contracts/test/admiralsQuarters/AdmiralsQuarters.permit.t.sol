// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuarters} from "../../src/contracts/AdmiralsQuarters.sol";
import {IAdmiralsQuartersEvents} from "../../src/events/IAdmiralsQuartersEvents.sol";
import {IDistributor} from "../../src/interfaces/merkl/IDistributor.sol";
import {ISignatureTransfer} from "../../src/interfaces/permit2/IPermit2.sol";
import {AdmiralsQuartersTest} from "./AdmiralsQuarters.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConfigurationManaged} from "@summerfi/config-contracts/contracts/ConfigurationManaged.sol";
import {Test, console} from "forge-std/Test.sol";

contract AdmiralsQuartersPermitTest is AdmiralsQuartersTest {
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
    }

    function test_enterFleetWithPermit() public {
        uint256 amount = 1000e6;
        uint256 deadline = block.timestamp + 100;

        // Use USDC for standard ERC2612 permit
        IERC20 token = IERC20(USDC_ADDRESS);

        // USDC uses version "2" for nonces
        uint256 nonce = _getUSDCNonce(address(token), owner);

        // Construct permit signature
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                owner,
                address(admiralsQuarters),
                amount,
                nonce,
                deadline
            )
        );

        bytes32 digest = _getUSDCDigest(address(token), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // The intent solver executes the transaction
        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);

        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit,
            (
                owner,
                address(usdcFleet),
                amount,
                "", // referralCode
                deadline,
                v,
                r,
                s
            )
        );
        vm.expectEmit(true, true, true, true);
        emit IAdmiralsQuartersEvents.FleetEntered(
            owner,
            address(usdcFleet),
            amount,
            amount
        );

        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // Verify allowance is used up
        assertEq(
            token.allowance(owner, address(admiralsQuarters)),
            0,
            "Allowance should be used up"
        );

        // Verify fleet shares convert to assets close to deposited amount
        uint256 shares = usdcFleet.balanceOf(owner);
        uint256 depositedAssets = usdcFleet.convertToAssets(shares);
        assertApproxEqAbs(
            depositedAssets,
            amount,
            2,
            "Shares should convert to approx deposited amount"
        );

        assertEq(
            token.balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have 0 balance"
        );
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
                "", // referralCode
                permit,
                signature
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IAdmiralsQuartersEvents.FleetEntered(
            owner,
            address(usdcFleet),
            amount,
            amount
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

    function test_exitFleetWithPermit2() public {
        uint256 amount = 1000e6;
        uint256 deadline = block.timestamp + 100;

        // 1. Setup: Owner enters fleet to get shares
        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(address(usdcFleet), amount);
        uint256 shares = usdcFleet.deposit(amount, owner);
        assertEq(usdcFleet.balanceOf(owner), shares);

        // Enable transfers for usdcFleet (needed for Permit2 transferFrom)
        vm.stopPrank();
        vm.prank(governor);
        usdcFleet.setFleetTokenTransferability();
        vm.startPrank(owner);

        // 2. Owner approves Permit2 for shares (needed for Permit2 to work)
        IERC20(address(usdcFleet)).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        // 3. User signs Permit2 transfer for shares
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(address(usdcFleet)),
                    amount: shares
                }),
                nonce: 0,
                deadline: deadline
            });

        bytes memory signature = _getPermit2Signature(
            permit,
            address(admiralsQuarters),
            ownerPrivateKey
        );

        // 4. Solver calls exitFleetWithPermit2 via multicall
        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.exitFleetWithPermit2,
            (owner, address(usdcFleet), permit, signature)
        );

        vm.expectEmit(true, true, true, true);
        emit IAdmiralsQuartersEvents.FleetExited(
            owner,
            address(usdcFleet),
            shares,
            amount
        );

        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // 5. Verify results
        assertEq(usdcFleet.balanceOf(owner), 0, "Shares should be burned");
        assertApproxEqAbs(
            IERC20(USDC_ADDRESS).balanceOf(owner),
            10000e6,
            2,
            "Owner should have received the USDC back"
        );
        assertEq(
            IERC20(address(usdcFleet)).balanceOf(address(admiralsQuarters)),
            0,
            "AQ should have no leftover shares"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AQ should have no leftover assets"
        );
    }

    function test_ExitSwapEnter_Permit2() public {
        uint256 usdcAmount = 1000e6;
        uint256 deadline = block.timestamp + 100;

        // 1. Setup: Owner enters USDC fleet to get shares
        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(address(usdcFleet), usdcAmount);
        uint256 usdcShares = usdcFleet.deposit(usdcAmount, owner);
        assertEq(usdcFleet.balanceOf(owner), usdcShares);

        // Enable transfers for usdcFleet (needed for Permit2 transferFrom)
        vm.stopPrank();
        vm.prank(governor);
        usdcFleet.setFleetTokenTransferability();
        vm.startPrank(owner);

        // 2. Setup approvals for Permit2 and AQ
        IERC20(address(usdcFleet)).approve(PERMIT2, type(uint256).max);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        IERC20(DAI_ADDRESS).approve(PERMIT2, type(uint256).max);
        // Pre-approve AQ for depositTokens call (this is the "round trip" part)
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();

        // 3. Prepare Sig 1: Exit USDC Fleet
        ISignatureTransfer.PermitTransferFrom
            memory exitPermit = ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(address(usdcFleet)),
                    amount: usdcShares
                }),
                nonce: 0,
                deadline: deadline
            });
        bytes memory exitSig = _getPermit2Signature(
            exitPermit,
            address(admiralsQuarters),
            ownerPrivateKey
        );

        // 4. Prepare Swap: USDC -> DAI
        uint256 minDaiAmount = 990e18;
        bytes memory usdcToDaiSwap = encodeUnoswapData(
            USDC_ADDRESS,
            usdcAmount,
            minDaiAmount,
            UNISWAP_USDC_DAI_V3_POOL,
            Protocol.UniswapV3,
            false,
            false,
            false,
            false
        );

        // 5. Prepare Sig 2: Enter DAI Fleet
        // We expect approx usdcAmount in DAI (since it's a stable swap)
        // Let's use a safe amount for the permit
        uint256 expectedDai = 995e18;
        ISignatureTransfer.PermitTransferFrom
            memory enterPermit = ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(DAI_ADDRESS),
                    amount: expectedDai
                }),
                nonce: 1, // Different nonce for second permit
                deadline: deadline
            });
        bytes memory enterSig = _getPermit2Signature(
            enterPermit,
            address(admiralsQuarters),
            ownerPrivateKey
        );

        // 6. Execute Multicall
        vm.startPrank(owner);
        bytes[] memory calls = new bytes[](5);

        // Step A: Exit USDC Fleet -> USDC to Owner
        calls[0] = abi.encodeCall(
            admiralsQuarters.exitFleetWithPermit2,
            (owner, address(usdcFleet), exitPermit, exitSig)
        );

        // Step B: Deposit USDC to AQ for swap
        calls[1] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), usdcAmount)
        );

        // Step C: Swap USDC to DAI
        calls[2] = abi.encodeCall(
            admiralsQuarters.swap,
            (
                IERC20(USDC_ADDRESS),
                IERC20(DAI_ADDRESS),
                usdcAmount,
                minDaiAmount,
                usdcToDaiSwap
            )
        );

        // Step D: Withdraw DAI to Owner (so enterFleetWithPermit2 can pull it)
        calls[3] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(DAI_ADDRESS), expectedDai)
        );

        // Step E: Enter DAI Fleet -> pulls from Owner
        calls[4] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, address(daiFleet), expectedDai, "", enterPermit, enterSig)
        );

        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // 7. Verify results
        assertEq(
            usdcFleet.balanceOf(owner),
            0,
            "USDC Fleet shares should be gone"
        );
        uint256 daiShares = daiFleet.balanceOf(owner);
        assertApproxEqAbs(
            daiShares,
            expectedDai,
            1e18,
            "Should have received DAI Fleet shares"
        );

        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AQ USDC balance 0"
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
