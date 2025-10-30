// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Errors} from "@openzeppelin/contracts/utils/Errors.sol";

contract MaliciousRefundReceiver {
    address public immutable adapter;

    constructor(address _adapter) {
        adapter = _adapter;
    }

    receive() external payable {
        // Attempt to reenter adapter entrypoint.
        // Refund uses a low gas cap; behavior is gas-sensitive, so adapter standardizes
        // any refund failure to Errors.FailedCall(). We still exercise a reenter attempt here.
        // NOTE: Intentionally perform an external call to exceed 2300 gas.
        (bool s, ) = adapter.call("");
        s; // silence warning
        revert("reenter");
    }
}

contract BenignRefundReceiver {
    event Received(uint256 amount);
    receive() external payable {
        emit Received(msg.value);
    }
}

contract StargateAdapterRefundReentrancyTest is StargateAdapterSetupTest {
    function testRefundWithMaliciousRefundAddressRevertsAndStateUnchanged()
        public
    {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        // Estimate the required fee
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        (uint256 requiredFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Prepare balances and approvals
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calc operation ID and register with router
        bytes32 operationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            operationId,
            address(adapterA)
        );

        // Deploy malicious refund receiver targeting the adapter
        MaliciousRefundReceiver malicious = new MaliciousRefundReceiver(
            address(adapterA)
        );

        // Build params; set malicious refundAddress
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(tokenA),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: address(malicious)
            });

        uint256 routerBalanceBefore = tokenA.balanceOf(address(routerA));
        uint256 adapterBalanceBefore = tokenA.balanceOf(address(adapterA));

        // Expect standardized revert due to refund failure (low-gas call mapped to Errors.FailedCall)
        vm.prank(address(routerA));
        vm.expectRevert(Errors.FailedCall.selector);
        adapterA.transferAsset{value: requiredFee + 1}(
            operationId,
            params,
            options
        );

        // State unchanged
        assertEq(tokenA.balanceOf(address(routerA)), routerBalanceBefore);
        assertEq(tokenA.balanceOf(address(adapterA)), adapterBalanceBefore);
    }

    function testRefundWithBenignRefundAddressSucceeds() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        (uint256 requiredFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        bytes32 operationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            operationId,
            address(adapterA)
        );

        BenignRefundReceiver benign = new BenignRefundReceiver();

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(tokenA),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: address(benign)
            });

        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee + 1}(
            operationId,
            params,
            options
        );
    }
}
