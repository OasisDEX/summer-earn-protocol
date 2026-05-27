// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {IAdmiralsQuartersEvents} from "../../src/events/IAdmiralsQuartersEvents.sol";
import {ISignatureTransfer} from "../../src/interfaces/permit2/IPermit2.sol";
import {AdmiralsQuartersWhitelistTest} from "./AdmiralsQuartersWhitelist.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract AdmiralsQuartersWhitelistPermitTest is AdmiralsQuartersWhitelistTest {
    using PercentageUtils for uint256;

    uint256 internal ownerPrivateKey;
    address internal owner;
    address internal solver;
    FleetCommanderWhitelist internal usdcFleet2;

    // Permit2 address on mainnet
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Correct Permit2 selectors
    bytes4 constant InvalidSigner = 0x815e1d64;
    bytes4 constant InvalidNonce = 0x756688fe;
    bytes4 constant SignatureExpired = 0xcd21db4f;

    bytes32 internal constant _FLEET_DEPOSIT_TYPEHASH =
        keccak256(
            "FleetDepositWitness(address fleetCommander,address receiver,bytes32 referralCode)"
        );

    string internal constant _WITNESS_TYPE_STRING =
        "FleetDepositWitness witness)FleetDepositWitness(address fleetCommander,address receiver,bytes32 referralCode)TokenPermissions(address token,uint256 amount)";

    function setUp() public override {
        super.setUp();

        ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);
        solver = address(0x1337);

        deal(USDC_ADDRESS, owner, 10000e6);
        deal(DAI_ADDRESS, owner, 10000e18);

        vm.label(owner, "Owner");
        vm.label(solver, "Solver");

        _setWhitelisted(address(usdcFleet), owner, true);

        // Setup a second USDC fleet for front-run tests
        usdcFleet2 = new FleetCommanderWhitelist(
            _fleetParams(
                USDC_ADDRESS,
                "USDC Fleet 2",
                "iUSDC2",
                uint256(0).fromIntegerPercentage(),
                true
            )
        );
        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(usdcFleet2));
        vm.prank(governor);
        accessManager.grantOperatorRole(
            address(usdcFleet2),
            address(admiralsQuarters)
        );
        vm.label(address(usdcFleet2), "USDC Fleet 2");
    }

    function test_enterFleetWithPermit2() public {
        uint256 amount = 1000e6;
        uint256 deadline = block.timestamp + 100;

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 0,
                deadline: deadline
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, address(usdcFleet), amount, "", owner, permit, signature)
        );

        vm.expectEmit(true, true, true, true, address(admiralsQuarters));
        emit IAdmiralsQuartersEvents.FleetEntered(
            owner,
            address(usdcFleet),
            amount,
            amount
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        assertEq(usdcFleet.balanceOf(owner), amount);
    }

    function test_enterFleetWithPermit2_WithReceiver() public {
        uint256 amount = 1000e6;
        address explicitReceiver = address(0x456);
        _setWhitelisted(address(usdcFleet), explicitReceiver, true);

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 1,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                explicitReceiver,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (
                owner,
                address(usdcFleet),
                amount,
                "",
                explicitReceiver,
                permit,
                signature
            )
        );

        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        assertEq(usdcFleet.balanceOf(explicitReceiver), amount);
        assertEq(usdcFleet.balanceOf(owner), 0);
    }

    function test_enterFleetWithPermit2_RevertOnWrongFleetCommander() public {
        uint256 amount = 1000e6;
        _setWhitelisted(address(usdcFleet2), owner, true);
        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 4,
                deadline: block.timestamp + 100
            });

        // Sign for usdcFleet
        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        // Submit for usdcFleet2 -> should fail signature verification in Permit2
        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, address(usdcFleet2), amount, "", owner, permit, signature)
        );

        vm.expectRevert(InvalidSigner);
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnWrongReceiver() public {
        uint256 amount = 1000e6;
        address wrongReceiver = address(0xBAD);

        _setWhitelisted(address(usdcFleet), wrongReceiver, true);

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 5,
                deadline: block.timestamp + 100
            });

        // Sign for owner as receiver
        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        // Submit with different receiver -> should fail signature verification
        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (
                owner,
                address(usdcFleet),
                amount,
                "",
                wrongReceiver,
                permit,
                signature
            )
        );

        vm.expectRevert(InvalidSigner);
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnReceiverNotWhitelisted()
        public
    {
        uint256 amount = 1000e6;
        address nonWhitelistedReceiver = address(0x999);

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 6,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                nonWhitelistedReceiver,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (
                owner,
                address(usdcFleet),
                amount,
                "",
                nonWhitelistedReceiver,
                permit,
                signature
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(usdcFleet),
                nonWhitelistedReceiver
            )
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnOwnerNotWhitelisted() public {
        uint256 amount = 1000e6;
        uint256 nonWhitelistedPK = 0xBAD1;
        address nonWhitelistedOwner = vm.addr(nonWhitelistedPK);
        deal(USDC_ADDRESS, nonWhitelistedOwner, amount);

        vm.startPrank(nonWhitelistedOwner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 7,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                nonWhitelistedOwner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            nonWhitelistedPK
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (
                nonWhitelistedOwner,
                address(usdcFleet),
                amount,
                "",
                nonWhitelistedOwner,
                permit,
                signature
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(usdcFleet),
                nonWhitelistedOwner
            )
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnInvalidFleetCommander() public {
        uint256 amount = 1000e6;
        address fakeFleet = address(0xDEADBEEF);
        _setWhitelisted(fakeFleet, owner, true);
        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 8,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(_FLEET_DEPOSIT_TYPEHASH, fakeFleet, owner, bytes32(0))
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, fakeFleet, amount, "", owner, permit, signature)
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnTokenMismatch() public {
        uint256 amount = 1000e6;

        vm.startPrank(owner);
        IERC20(DAI_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(DAI_ADDRESS),
                    amount: amount
                }),
                nonce: 9,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, address(usdcFleet), amount, "", owner, permit, signature)
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnAmountMismatch() public {
        uint256 amount = 1000e6;

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 10,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (
                owner,
                address(usdcFleet),
                amount + 1,
                "",
                owner,
                permit,
                signature
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnExpiredDeadline() public {
        uint256 amount = 1000e6;
        uint256 deadline = block.timestamp - 1;

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 11,
                deadline: deadline
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, address(usdcFleet), amount, "", owner, permit, signature)
        );

        vm.expectRevert(abi.encodeWithSelector(SignatureExpired, deadline));
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_enterFleetWithPermit2_RevertOnReplayedSignature() public {
        uint256 amount = 1000e6;

        vm.startPrank(owner);
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        vm.stopPrank();

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(USDC_ADDRESS),
                    amount: amount
                }),
                nonce: 12,
                deadline: block.timestamp + 100
            });

        bytes32 witnessHash = keccak256(
            abi.encode(
                _FLEET_DEPOSIT_TYPEHASH,
                address(usdcFleet),
                owner,
                bytes32(0)
            )
        );

        bytes memory signature = _getPermit2WitnessSignature(
            permit,
            address(admiralsQuarters),
            witnessHash,
            _WITNESS_TYPE_STRING,
            ownerPrivateKey
        );

        vm.startPrank(solver);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.enterFleetWithPermit2,
            (owner, address(usdcFleet), amount, "", owner, permit, signature)
        );

        admiralsQuarters.multicall(calls);

        // Replay same call
        vm.expectRevert(InvalidNonce);
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function _getPermit2WitnessSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        bytes32 witnessHash,
        string memory witnessTypeString,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 TOKEN_PERMISSIONS_TYPEHASH = keccak256(
            "TokenPermissions(address token,uint256 amount)"
        );

        bytes32 typeHash = keccak256(
            abi.encodePacked(
                "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,",
                witnessTypeString
            )
        );

        bytes32 domainSeparator = ISignatureTransfer(PERMIT2)
            .DOMAIN_SEPARATOR();

        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                TOKEN_PERMISSIONS_TYPEHASH,
                permit.permitted.token,
                permit.permitted.amount
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                tokenPermissionsHash,
                spender,
                permit.nonce,
                permit.deadline,
                witnessHash
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
