// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IInflightAssetTracking} from "../../src/interfaces/IInflightAssetTracking.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

contract OriginatorInflight is IInflightAssetTracking {
    uint256 public lastInflightAmount;

    function updateInflightAssets(uint256 amount) external {
        lastInflightAmount = amount;
        emit InflightAssetsUpdated(amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IInflightAssetTracking).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}

contract BridgeRouterInflightTest is BridgeRouterSetup {
    function testExecuteTransferAssetsUpdatesInflightOnOriginator() public {
        // Deploy an originator contract that supports IInflightAssetTracking
        OriginatorInflight originator = new OriginatorInflight();

        // Register originator as an authorized executor
        vm.startPrank(governor);
        registry.registerExecutor(address(originator));
        vm.stopPrank();

        // Fund originator with tokens and approve router
        uint256 amount = 1234 ether;
        token.mint(address(originator), amount);

        vm.startPrank(address(originator));
        token.approve(address(router), amount);

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: amount,
                target: user,
                originator: address(originator),
                refundAddress: address(originator),
                message: ""
            });

        router.executeTransferAssets(params, options);
        vm.stopPrank();

        // Verify the originator recorded the in-flight amount
        assertEq(
            originator.lastInflightAmount(),
            amount,
            "inflight not updated"
        );
    }
}
