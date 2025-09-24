// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IAssetAdapter} from "../../src/interfaces/IAssetAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {BridgeOptionsTestHelper} from "../helpers/BridgeOptionsTestHelper.sol";

contract BridgeRouterTransferTest is BridgeRouterSetup {
    using BridgeOptionsTestHelper for address;

    function testExecuteTransferAssets_Succeeds() public {
        // User initiates
        vm.startPrank(user);

        // Create bridge options via helper
        BridgeTypes.BridgeOptions memory options = address(mockAdapter)
            .defaultOptions();

        // Get a quote first to determine the required fee FOR EXECUTION
        (uint256 nativeFee, , address specifiedAdapter) = router
            .quoteTransferAssets(
                BridgeTypes.ExecuteTransferParams({
                    originator: user,
                    destinationChainId: DEST_CHAIN_ID,
                    target: recipient,
                    asset: address(token),
                    amount: TRANSFER_AMOUNT,
                    message: "",
                    refundAddress: user
                }),
                options
            );
        // vm.deal(user, nativeFee); // REMOVED: User no longer pays fee

        // Verify the specified adapter matches what we provided
        assertEq(specifiedAdapter, address(mockAdapter));

        vm.stopPrank(); // User stops queueing

        // Keeper executes (PAYS THE FEE)
        vm.startPrank(keeper);
        // approve tokens for transfer
        token.approve(address(router), TRANSFER_AMOUNT);
        // Execute with value - Fixed: added options parameter
        bytes32 operationId = router.executeTransferAssets{value: nativeFee}(
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                target: user,
                originator: keeper,
                refundAddress: address(keeper),
                message: ""
            }),
            options
        );
        vm.stopPrank();
    }

    function testQuoteTransferAssets_NoAdapter_Reverts() public {
        vm.startPrank(user);

        // Create bridge options - no adapter
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .noAdapter();

        // Should revert when no adapter is specified
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quoteTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: DEST_CHAIN_ID,
                target: recipient,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                message: "",
                refundAddress: user
            }),
            options
        );

        vm.stopPrank();
    }

    function testExecuteTransferAssets_ZeroGasLimitReverts() public {
        vm.startPrank(keeper);

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 0,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: 1,
                target: user,
                originator: keeper,
                refundAddress: keeper,
                message: ""
            });

        vm.expectRevert(IBridgeRouter.ZeroGasLimit.selector);
        router.executeTransferAssets(params, options);

        vm.stopPrank();
    }
}
