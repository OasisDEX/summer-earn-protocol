// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test} from "forge-std/Test.sol";

abstract contract TransferHelpers is Test {
    uint64 internal constant DEFAULT_GAS_LIMIT = 500000;

    function defaultBridgeOptions(
        address specifiedAdapter
    ) internal pure returns (BridgeTypes.BridgeOptions memory) {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: specifiedAdapter,
                gasLimit: DEFAULT_GAS_LIMIT,
                calldataSize: 0,
                msgValue: 0,
                options: "",
                payInProtocolToken: false,
                feeToken: address(0)
            });
    }

    function buildExecuteTransferParams(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address target,
        address originator,
        address refundAddress
    ) internal pure returns (BridgeTypes.ExecuteTransferParams memory) {
        return
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: destinationChainId,
                asset: asset,
                amount: amount,
                target: target,
                originator: originator,
                message: "",
                refundAddress: refundAddress
            });
    }

    function fundRouterAndApprove(
        ERC20Mock token,
        address router,
        address adapter,
        address from,
        uint256 amount
    ) internal {
        vm.prank(from);
        require(token.transfer(router, amount));
        vm.prank(router);
        token.approve(adapter, amount);
    }
}
