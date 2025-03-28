# Cross-Chain Infrastructure Todo List

## Completed Tasks

### Core Infrastructure
- [x] Create bridging router + interface
- [x] Create bridging router implementation
- [x] Create bridging router tests
- [x] Create adapter interface
- [x] Create bridging router documentation

### Adapters Implementation
- [x] Create LayerZero adapter
- [x] Create Stargate adapter
- [x] Ensure cross-chain messaging on receipt triggers a notification back to the source chain via the destination chain router
- [x] Consider how messages are paid for (especially on target chains when notifying the source chain)

### LayerZero Specific
- [x] Create LayerZero adapter tests
- [x] Test send read functionality on LayerZero
- [x] Confirm received reads update to COMPLETED
- [x] Confirm confirmation messages are processed

### Stargate Specific
- [x] Create Stargate adapter tests

### Code Improvements & Refactoring
- [x] Review status naming (e.g., transferStatus vs messageStatus)
- [x] Pull shared events/errors into adapter interface
- [x] Update mappings that still read "transfer" and update to "message"
- [x] Update confirmation gas 
- [x] Review if confirmation message receipt handling is correct
- [x] Review _isStatusProgression to see if it can be used in more places

## Pending Tasks
- [ ] How to handle bridging executions - access control or queued jobs?
- [x] Guids on _lzSend // not sure this works
- [ ] Add fees back in

### Integration Testing
- [ ] Integration tests with StargateRouter — all via BridgeRouter
  * Implement comprehensive tests for message sending and receiving
  * Test error handling and recovery scenarios
  * Validate gas optimization for cross-chain operations
- [ ] Integration tests with LZEndpoint — all via BridgeRouter
  * Test end-to-end message flow across chains
  * Verify correct status updates throughout the message lifecycle
  * Simulate network issues to test reliability

### Documentation
- [ ] Create LayerZero adapter documentation
  * Include architecture diagrams
  * Document configuration options and gas requirements
  * Add examples for common integration patterns
- [ ] Create Stargate adapter documentation
  * Explain router configuration and supported chains
  * Document message format and payload requirements
  * Provide troubleshooting guides for common issues 