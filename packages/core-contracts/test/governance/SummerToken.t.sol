// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../../src/contracts/SummerToken.sol";
import "forge-std/Test.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IOAppOptionsType3, EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

contract SummerTokenTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    SummerToken public aSummerToken;
    SummerToken public bSummerToken;

    address public user1;
    address public user2;

    address public owner = address(this);
    address public summerGovernor = address(this);

    uint256 constant INITIAL_SUPPLY = 1000000000;

    function setUp() public override {
        super.setUp();
        vm.label(summerGovernor, "Summer Governor");

        setUpEndpoints(2, LibraryType.UltraLightNode);

        user1 = address(0x1);
        user2 = address(0x2);

        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);

        address lzEndpointA = address(endpoints[aEid]);
        address lzEndpointB = address(endpoints[bEid]);
        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");

        SummerToken.TokenParams memory tokenParamsA = SummerToken.TokenParams({
            name: "SummerToken A",
            symbol: "SUMMERA",
            lzEndpoint: lzEndpointA,
            governor: summerGovernor
        });

        SummerToken.TokenParams memory tokenParamsB = SummerToken.TokenParams({
            name: "SummerToken B",
            symbol: "SUMMERB",
            lzEndpoint: lzEndpointB,
            governor: summerGovernor
        });

        aSummerToken = new SummerToken(tokenParamsA);
        bSummerToken = new SummerToken(tokenParamsB);

        // Config and wire the tokens
        address[] memory tokens = new address[](2);
        tokens[0] = address(aSummerToken);
        tokens[1] = address(bSummerToken);

        this.wireOApps(tokens);
    }

    function test_InitialSupply() public view {
        assertEq(aSummerToken.totalSupply(), INITIAL_SUPPLY * 10 ** 18);
        assertEq(bSummerToken.totalSupply(), INITIAL_SUPPLY * 10 ** 18);
    }

    function test_OwnerBalance() public view {
        assertEq(aSummerToken.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18);
        assertEq(bSummerToken.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18);
    }

    function test_TokenNameAndSymbol() public view {
        assertEq(aSummerToken.name(), "SummerToken A");
        assertEq(aSummerToken.symbol(), "SUMMERA");
        assertEq(bSummerToken.name(), "SummerToken B");
        assertEq(bSummerToken.symbol(), "SUMMERB");
    }

    function test_Transfer() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        assertEq(aSummerToken.balanceOf(user1), amount);
        assertEq(
            aSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );

        bSummerToken.transfer(user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(
            bSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
    }

    function testFail_TransferInsufficientBalance() public {
        uint256 amount = (INITIAL_SUPPLY + 1) * 10 ** 18;
        aSummerToken.transfer(user1, amount);
        bSummerToken.transfer(user2, amount);
    }

    function test_ApproveAndTransferFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount);
        assertEq(aSummerToken.allowance(owner, user1), amount);

        vm.prank(user1);
        aSummerToken.transferFrom(owner, user2, amount);
        assertEq(aSummerToken.balanceOf(user2), amount);
        assertEq(aSummerToken.allowance(owner, user1), 0);

        bSummerToken.approve(user1, amount);
        assertEq(bSummerToken.allowance(owner, user1), amount);

        vm.prank(user1);
        bSummerToken.transferFrom(owner, user2, amount);
        assertEq(bSummerToken.balanceOf(user2), amount);
        assertEq(bSummerToken.allowance(owner, user1), 0);
    }

    function testFail_TransferFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        aSummerToken.transferFrom(owner, user2, amount);

        bSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        bSummerToken.transferFrom(owner, user2, amount);
    }

    function test_Burn() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 initialSupplyA = aSummerToken.totalSupply();
        uint256 initialSupplyB = bSummerToken.totalSupply();

        aSummerToken.burn(amount);
        assertEq(aSummerToken.balanceOf(owner), initialSupplyA - amount);
        assertEq(aSummerToken.totalSupply(), initialSupplyA - amount);

        bSummerToken.burn(amount);
        assertEq(bSummerToken.balanceOf(owner), initialSupplyB - amount);
        assertEq(bSummerToken.totalSupply(), initialSupplyB - amount);
    }

    function testFail_BurnInsufficientBalance() public {
        uint256 amount = (INITIAL_SUPPLY + 1) * 10 ** 18;
        aSummerToken.burn(amount);
        bSummerToken.burn(amount);
    }

    function test_BurnFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount);

        vm.prank(user1);
        aSummerToken.burnFrom(owner, amount);

        assertEq(
            aSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(
            aSummerToken.totalSupply(),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(aSummerToken.allowance(owner, user1), 0);

        bSummerToken.approve(user1, amount);

        vm.prank(user1);
        bSummerToken.burnFrom(owner, amount);

        assertEq(
            bSummerToken.balanceOf(owner),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(
            bSummerToken.totalSupply(),
            (INITIAL_SUPPLY * 10 ** 18) - amount
        );
        assertEq(bSummerToken.allowance(owner, user1), 0);
    }

    function testFail_BurnFromInsufficientAllowance() public {
        uint256 amount = 1000 * 10 ** 18;
        aSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        aSummerToken.burnFrom(owner, amount);

        bSummerToken.approve(user1, amount - 1);

        vm.prank(user1);
        bSummerToken.burnFrom(owner, amount);
    }

    function test_OFTSend() public {
        uint256 tokensToSend = 1 ether;
        aSummerToken.transfer(user1, tokensToSend);
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(user2),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        console.log(
            "aSummerToken.balanceOf(user1)",
            aSummerToken.balanceOf(user1)
        );
        assertEq(aSummerToken.balanceOf(user1), tokensToSend);
        assertEq(bSummerToken.balanceOf(user2), 0);

        vm.prank(user1);
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));

        assertEq(aSummerToken.balanceOf(user1), 0);
        assertEq(bSummerToken.balanceOf(user2), tokensToSend);
    }

    function test_OFTSendWithCompose() public {
        uint256 tokensToSend = 1 ether;
        aSummerToken.transfer(user1, tokensToSend);

        // Deploy a mock composer contract
        OFTComposerMock composer = new OFTComposerMock();

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 500000, 0);
        bytes memory composeMsg = hex"1234";
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(address(composer)),
            tokensToSend,
            tokensToSend,
            options,
            composeMsg,
            ""
        );
        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        assertEq(aSummerToken.balanceOf(user1), tokensToSend);
        assertEq(bSummerToken.balanceOf(address(composer)), 0);

        vm.prank(user1);
        (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        ) = aSummerToken.send{value: fee.nativeFee}(
                sendParam,
                fee,
                payable(address(this))
            );
        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));

        // lzCompose params
        uint32 dstEid_ = bEid;
        address from_ = address(bSummerToken);
        bytes memory options_ = options;
        bytes32 guid_ = msgReceipt.guid;
        address to_ = address(composer);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            aEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(user1), composeMsg)
        );
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertEq(aSummerToken.balanceOf(user1), 0);
        assertEq(bSummerToken.balanceOf(address(composer)), tokensToSend);

        assertEq(composer.from(), from_);
        assertEq(composer.guid(), guid_);
        assertEq(composer.message(), composerMsg_);
        assertEq(composer.executor(), address(this));
        assertEq(composer.extraData(), composerMsg_);
    }
}

// Mock contract for OFT compose testing
contract OFTComposerMock {
    address public from;
    bytes32 public guid;
    bytes public message;
    address public executor;
    bytes public extraData;

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata
    ) external payable {
        from = _from;
        guid = _guid;
        message = _message;
        executor = _executor;
        extraData = _message; // We set extraData to the message for testing
    }
}
