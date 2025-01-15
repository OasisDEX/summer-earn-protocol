// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
contract SummerTokenOFTTest is SummerTokenTestBase {
    using OptionsBuilder for bytes;

    function test_SendTokens() public {
        enableTransfers();
        uint256 amount = 100 ether;
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(address(0x2)),
            amount,
            (amount * 9900) / 10000, // 1% slippage
            options,
            "",
            ""
        );

        MessagingFee memory fee = aSummerToken.quoteSend(sendParam, false);

        vm.prank(owner);
        aSummerToken.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );

        verifyPackets(bEid, addressToBytes32(address(bSummerToken)));
    }

    function test_RevertWhenSlippageExceeded() public {
        uint256 amount = 100 ether;
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam(
            bEid,
            OFTMsgCodec.addressToBytes32(address(bSummerToken)),
            amount,
            amount + 1, // Set minAmount higher than amount to trigger slippage protection
            options,
            "",
            ""
        );

        vm.expectRevert(
            abi.encodeWithSignature(
                "SlippageExceeded(uint256,uint256)",
                amount,
                amount + 1
            )
        );
        aSummerToken.quoteSend(sendParam, false);
    }
}
