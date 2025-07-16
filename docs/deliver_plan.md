High-level goal  
Move the "last hop" of every cross-chain message/asset flow into`BridgeRouter.deliver(…)`, so that:

StargateAdapter  ➜  BridgeRouter.deliver  ➜  end-recipient  
No adapter talks to the user‐contract directly any more.

──────────────────────────────────────────
Implementation plan
──────────────────────────────────────────
1. Prerequisites
   a. Make sure the Stargate adapter is already registered in the router on every   chain (`BridgeRouter.registerAdapter`).  
   b. Verify that `BridgeRouter.deliver` already does everything we need (asset   transfer, receiver-callbacks, events, status bookkeeping).

2. Adapter changes (packages/chain-bridge/src/adapters/StargateAdapter.sol)

   2.1  Remove the "direct delivery" path  
        • Delete `_tryDeliverAssets` (and its only caller).  
        • Delete `emit TransferReceived` / `emit MessageDelivered` that belonged          to that path – the router will emit them now.  

   2.2  In `_handleAssetTransferMessage(…)`  
        Step-by-step replacement:  
        1. Transfer the tokens you just received from Stargate over to the           router:  
              IERC20(receivedAsset).safeTransfer(bridgeRouter(), amount);  
        2. Build the payload you want the destination contract to get  
              bytes memory payload = abi.encode(
                  operationId,
                  originator,
                  sourceAsset
              );  
        3. Call the router (the adapter is a registered adapter, so the           modifier will pass):  
              IBridgeRouter(bridgeRouter()).deliver(
                  operationId,
                  uint16(sourceChainId),
                  receivedAsset,
                  amount,
                  recipient,
                  payload
              );  
        4. Return (no further logic – the router took over).  

   2.3  Pure-message path  
        If at some point StargateAdapter supports MESSAGE / READ_STATE, call        the same function with `asset = address(0)` and `amount = 0` and skip        the token transfer in step 1 above.

   2.4  Fleet-deposit compose messages  
        These deliberately bypass the generic delivery flow because they need        to interact with FleetCommander.  Leave the existing logic untouched.

   2.5  Events  
        Remove any events that become duplicates of the router's events.  
        Keep adapter-specific events such as `ComposedAssetHandled`,        `CrossChainFleetDeposit*`, etc.

3. Adapter changes (packages/chain-bridge/src/adapters/LayerZeroAdapter.sol)

   3.1  Remove the current "direct delivery" path  
        • Delete the body of `_handleGeneralMessage` that tries to call the  
          recipient directly and emits its own events.  
        • Drop `_updateReceiveStatus(…, FAILED)` logic that was only needed  
          when the adapter managed delivery itself.

   3.2  Forward every general message to the router instead:  

        ```solidity
        // inside _handleGeneralMessage(...)
        bytes memory payload = message;                 // what end-recipient expects
        try IBridgeRouter(bridgeRouter()).deliver(
                messageId,                              // operationId
                srcChainId,                             // originating chain
                address(0),                             // no asset
                0,                                      // no amount
                recipient,
                payload
        ) {
            // nothing else – BridgeRouter emits events & tracks status
        } catch (bytes memory reason) {
            _updateReceiveStatus(
                messageId,
                recipient,
                BridgeTypes.OperationStatus.FAILED
            );
            emit RelayFailed(messageId, reason);
        }
        ```

        Notes:  
        • `messageId` (decoded from the payload) becomes `operationId`.  
        • `payload` is passed unchanged so `receiveMessage` gets the exact
          bytes expected.  
        • If `deliver` reverts, we preserve the previous failure-handling
          behaviour.

   3.3  Remove `emit MessageDelivered` in the adapter – the router now fires it.  

   3.4  No change needed for read-state responses (`deliverReadResponse` is
        already used).

4. BridgeRouter – no code changes needed  
   • `deliver` already:  
        – records which adapter handled the request  
        – moves tokens from itself to the recipient (they will be sitting          there because the adapter forwards them first)  
        – calls the correct callback on the recipient  
        – emits the canonical events

5. Tests / scripts
   • Update tests that listened to `MessageDelivered` from the adapter – now
     expect it from the router.  
   • Add regression test for a pure message flow via LayerZeroAdapter →
     BridgeRouter.deliver.

6. Deployment / migrations
   • No storage layout changes; only behaviour.  
   • Roll out new byte-code for the adapter, register it if addresses change.  
   • Existing operations in flight are unaffected (they will still use the old     adapter implementation on-chain).

7. Optional clean-up
   • Delete unused helpers/events from LayerZeroAdapter after refactor.  
   • Update docs: "All inbound deliveries go through BridgeRouter".

──────────────────────────────────────────
Checklist
──────────────────────────────────────────
☐ StargateAdapter: tokens forwarded then `deliver` called  
☐ LayerZeroAdapter: general messages forwarded via `deliver`  
☐ `deliver` invoked with correct params for all paths  
☐ Redundant events & helpers removed from both adapters  
☐ Tests updated (expect router events, not adapter events)  
☐ Deployment scripts adjusted (if needed)