# ERC7802 OFT Compose Integration Implementation Plan

## Overview

This document outlines the implementation plan for adding **compose message support** to the ERC7802 OFT adapters using LayerZero's OFT compose functionality. This enables "asset transfers with messages" in a single atomic operation.

## Architecture Decision

**Focused Scope:**
- **ERC7802OFTAdapter**: Asset transfers with optional compose messages
- **LayerZeroAdapter**: Pure messaging + state reads (existing functionality)

**Why this approach:**
- ✅ Leverages OFT's native compose capabilities for atomic transfers + messages
- ✅ Keeps pure messaging on dedicated LZ adapter (better separation of concerns)
- ✅ Single LayerZero message for both tokens + message (cost efficient)
- ✅ Maintains existing BridgeRouter integration patterns

## Implementation Phases

### Phase 1: Core OFT Compose Integration

#### 1.1 Base Infrastructure
- [ ] **inherit-message-interface**: Add `IMessageAdapter` interface inheritance to `BaseERC7802Adapter` (minimal interface for compose support)
- [ ] **update-supports-operation**: Update `supportsOperation()` to maintain `TRANSFER_ASSET` support only
- [ ] **add-lz-endpoint-integration**: Add LayerZero endpoint integration for compose functionality
- [ ] **add-compose-message-helpers**: Add helper functions for OFT compose message encoding/decoding

#### 1.2 Transfer Flow Enhancement
- [ ] **modify-send-transport**: Modify `_sendTransport()` to use `composeMsg` when message is provided in transfer params
- [ ] **implement-lz-compose**: Implement `_lzCompose()` function to handle incoming OFT compose messages (tokens + message)
- [ ] **update-estimation-functions**: Update `estimateTransferAssets()` to account for compose message costs when message is present

### Phase 2: Error Handling and Governance

#### 2.1 Error Handling
- [ ] **add-compose-error-handling**: Add comprehensive error handling for compose message failures
- [ ] **add-compose-recovery**: Add recovery mechanisms for failed compose operations
- [ ] **add-compose-validation**: Add validation for compose message size limits and content

#### 2.2 Governance Functions
- [ ] **add-compose-governance**: Add governance functions for compose message limits and gas configuration
- [ ] **add-compose-limits**: Add configurable limits for compose message sizes and gas costs
- [ ] **add-emergency-pause**: Add emergency pause functionality for compose operations

### Phase 3: Testing and Documentation

#### 3.1 Testing
- [ ] **test-compose-functionality**: Add unit and integration tests for compose message functionality
- [ ] **test-compose-failures**: Add tests for compose failure scenarios and recovery mechanisms
- [ ] **test-compose-limits**: Add tests for compose message size and gas limit validations

#### 3.2 Documentation and Security
- [ ] **update-compose-documentation**: Update README and inline documentation for compose messaging capabilities
- [ ] **create-compose-integration-guide**: Create integration guide for using compose features
- [ ] **security-review-compose**: Add security review for compose message handling

## Key Technical Decisions

### 1. Compose-Only Approach
**Decision**: OFT adapter handles only asset transfers with optional compose messages
- **Pros**: Clean separation of concerns, leverages OFT's strengths
- **Cons**: No pure messaging capability in OFT adapter
- **Mitigation**: Use dedicated LZ adapter for pure messaging needs

### 2. Compose Message Encoding Strategy
**Decision**: Embed full transfer params (including message) in OFT `composeMsg` field
- **Pros**: Atomic token + message delivery, single LayerZero message
- **Cons**: Slightly higher gas costs due to compose overhead
- **Mitigation**: Only use compose when message is actually provided

### 3. Error Recovery Strategy
**Decision**: LayerZero's built-in retry mechanisms + governance recovery
- **Primary**: LZ automatic retries for failed deliveries
- **Secondary**: Governance manual recovery for stuck operations
- **Fallback**: Emergency pause for critical issues

## Implementation Dependencies

### External Dependencies
- LayerZero OApp contracts (`@layerzerolabs/oapp-evm`)
- LayerZero messaging libraries (`@layerzerolabs/lz-evm-protocol-v2`)
- OFT compose utilities (`@layerzerolabs/oft-evm`)

### Internal Dependencies
- `CrossChainConfigManaged` for registry integration
- `BridgeTypes` for message structure definitions
- `BridgeCodec` for payload encoding/decoding
- `BaseBridgeAdapter` for common functionality

## Risk Assessment

### High Risk
- **Message ordering**: Ensure messages are processed in correct order
- **Replay attacks**: Prevent duplicate message processing
- **Gas estimation**: Accurate gas estimation for compose operations

### Medium Risk
- **Message size limits**: Handle large message payloads efficiently
- **Cross-chain delays**: Manage timing dependencies between chains
- **Cost optimization**: Balance functionality with gas costs

### Low Risk
- **Backward compatibility**: Ensure existing transfer functionality unchanged
- **Error handling**: Comprehensive error recovery mechanisms
- **Monitoring**: Adequate event emission for operational monitoring

## Success Criteria

### Functional Requirements
- [ ] ERC7802OFTAdapter can send asset transfers with optional compose messages
- [ ] ERC7802OFTAdapter can receive and process OFT compose messages (tokens + message)
- [ ] Compose operations maintain atomicity (tokens + message delivered together)
- [ ] LayerZeroAdapter continues to handle pure messaging + state reads
- [ ] Error recovery mechanisms work for compose failures

### Non-Functional Requirements
- [ ] Gas costs for compose transfers remain reasonable vs separate operations
- [ ] Compose message latency is acceptable for transfer + message use cases
- [ ] System maintains existing BridgeRouter integration patterns
- [ ] Security audit passes with no critical issues for compose functionality

## Migration Strategy

### Phase 1: Parallel Implementation
- Implement new messaging capabilities alongside existing transfer functionality
- Maintain backward compatibility with existing integrations
- Allow gradual migration of users to new features

### Phase 2: Feature Flag Rollout
- Use governance-controlled feature flags to enable messaging
- Start with limited chains and gradually expand
- Monitor performance and costs during rollout

### Phase 3: Full Migration
- Deprecate old transfer-only endpoints (if any)
- Update documentation and examples
- Communicate changes to ecosystem participants

## Monitoring and Maintenance

### Key Metrics to Track
- Message success/failure rates
- Average gas costs per operation
- Message latency (end-to-end)
- Compose message processing times
- Error recovery effectiveness

### Operational Procedures
- Regular gas cost monitoring and optimization
- Message queue monitoring for congestion
- Automated alerts for high error rates
- Regular security audits of message handling logic

## Next Steps

1. **Immediate**: Start with Phase 1 core interface changes
2. **Week 1-2**: Complete Phase 1 and begin Phase 2
3. **Week 3-4**: Complete implementation and begin testing
4. **Week 5-6**: Security review and mainnet deployment preparation

---

*This implementation plan was generated based on analysis of the existing BridgeRouter system and LayerZero OFT capabilities. Last updated: September 19, 2025*
