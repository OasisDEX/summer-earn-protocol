# CrossChain Registry Implementation Plan

## Overview
Create a `CrossChainRegistry` contract that centralizes the management of relationships between `CrossChainArk` contracts and `FleetProxy` contracts across different chains. This will replace the current setter-based approach with a more structured registry system.

## Current State Analysis
- **CrossChainArk**: Uses `targetProxy` field, set via `setTargetProxy()`
- **FleetProxy**: Uses `sourceChainArk` field, set via `setSourceChainArk()`
- Both use governor-only setters for configuration
- No central tracking or validation of relationships
- Deployment scripts handle configuration post-deployment

## Design Goals
1. **Centralized Management**: Single source of truth for cross-chain relationships
2. **Enhanced Security**: Better access control and validation
3. **Improved Observability**: Events and queries for relationship tracking
4. **Future-Proof**: Support for potential one-to-many relationships
5. **Backward Compatibility**: Minimal disruption to existing contracts

## Implementation Tasks

### Phase 1: Registry Contract Creation

#### 1.1 Create CrossChainRegistry Interface
- [ ] Create `ICrossChainRegistry.sol` interface
- [ ] Define core functions:
  - `registerArkProxy(address ark, uint16 targetChainId, address proxy)`
  - `unregisterArkProxy(address ark)`
  - `getProxyForArk(address ark) returns (address, uint16)`
  - `getArkForProxy(uint16 sourceChainId, address proxy) returns (address)`
  - `isValidArkProxyPair(address ark, uint16 targetChainId, address proxy) returns (bool)`
- [ ] Define events:
  - `ArkProxyRegistered(address indexed ark, uint16 indexed targetChainId, address indexed proxy)`
  - `ArkProxyUnregistered(address indexed ark, uint16 indexed targetChainId, address indexed proxy)`

#### 1.2 Implement CrossChainRegistry Contract
- [ ] Create `CrossChainRegistry.sol` contract
- [ ] Inherit from `ProtocolAccessManaged` for access control
- [ ] Implement storage structure:
  ```solidity
  struct ArkProxyRelation {
      address proxy;
      uint16 targetChainId;
      bool isActive;
  }
  mapping(address => ArkProxyRelation) private arkToProxy;
  mapping(bytes32 => address) private proxyToArk; // keccak256(abi.encode(sourceChainId, proxy))
  ```
- [ ] Implement registration logic with validation
- [ ] Add governor-only functions for emergency management
- [ ] Include comprehensive error handling

#### 1.3 Add Registry Integration Points
- [ ] Create getter functions for easy integration:
  - `getRegisteredArks() returns (address[])`
  - `getRegisteredProxies(uint16 chainId) returns (address[])`
  - `getRelationshipCount() returns (uint256)`
- [ ] Add pagination support for large datasets
- [ ] Include relationship validation helpers

### Phase 2: Contract Integration

#### 2.1 Modify CrossChainArk Contract
- [ ] Add `CrossChainRegistry` reference as immutable variable
- [ ] Modify `_board()` to use registry: `registry.getProxyForArk(address(this))`
- [ ] Update `requestRemoteAssetBalanceUpdate()` to use registry
- [ ] Add validation in constructor to ensure registry is set
- [ ] Keep `targetProxy` as fallback for backward compatibility (mark as deprecated)
- [ ] Add migration function to register with registry

#### 2.2 Modify FleetProxy Contract
- [ ] Add `CrossChainRegistry` reference as immutable variable
- [ ] Modify `withdrawAndTransfer()` to use registry for source ark lookup
- [ ] Add validation to ensure proxy is registered in constructor
- [ ] Keep `sourceChainArk` as fallback for backward compatibility (mark as deprecated)
- [ ] Add helper function to validate incoming cross-chain messages against registry

#### 2.3 Add Registry Deployment Support
- [ ] Create `CrossChainRegistryModule` for Ignition deployment
- [ ] Update deployment scripts to deploy registry first
- [ ] Modify CrossChainArk deployment to include registry address
- [ ] Modify FleetProxy deployment to include registry address

### Phase 3: Enhanced Features

#### 3.1 Advanced Registry Features
- [ ] Add support for relationship metadata:
  ```solidity
  struct RelationshipMetadata {
      string description;
      uint256 createdAt;
      address creator;
      bytes32 configHash;
  }
  ```
- [ ] Implement relationship history tracking
- [ ] Add batch registration functions for efficient multi-setup
- [ ] Include relationship status management (active, paused, deprecated)

#### 3.2 Validation and Security
- [ ] Add contract existence validation for registered addresses
- [ ] Implement chain ID validation against supported chains
- [ ] Add rate limiting for registration changes
- [ ] Include emergency pause functionality
- [ ] Add multi-signature requirements for critical operations

#### 3.3 Monitoring and Analytics
- [ ] Add comprehensive events for all state changes
- [ ] Include relationship health check functions
- [ ] Add statistics tracking (total relationships, by chain, etc.)
- [ ] Implement alerting for broken relationships

### Phase 4: Migration and Testing

#### 4.1 Migration Strategy
- [ ] Create migration scripts for existing deployments
- [ ] Implement gradual rollout plan
- [ ] Add backward compatibility verification
- [ ] Create registry population scripts from existing configs

#### 4.2 Testing Suite
- [ ] Unit tests for registry contract
- [ ] Integration tests with CrossChainArk and FleetProxy
- [ ] Fork tests with real deployment scenarios
- [ ] Gas optimization analysis
- [ ] Security audit preparation

#### 4.3 Documentation and Deployment
- [ ] Update deployment documentation
- [ ] Create registry management guides
- [ ] Add troubleshooting documentation
- [ ] Update existing script documentation

### Phase 5: Advanced Features (Future)

#### 5.1 Multi-Chain Registry
- [ ] Consider cross-chain registry synchronization
- [ ] Implement registry state reading across chains
- [ ] Add cross-chain validation mechanisms

#### 5.2 Governance Integration
- [ ] Add governance proposal templates for registry changes
- [ ] Implement voting mechanisms for relationship changes
- [ ] Add time-locked changes for critical updates

## Technical Considerations

### Access Control
- **Governor**: Full registry management, emergency functions
- **Keeper**: Read-only access, health checks
- **Public**: Read-only relationship queries

### Gas Optimization
- Use packed structs where appropriate
- Implement efficient iteration patterns
- Consider storage vs memory trade-offs
- Add view function gas benchmarks

### Error Handling
- Comprehensive custom errors
- Clear error messages for debugging
- Graceful degradation for missing relationships
- Fallback mechanisms for compatibility

### Event Design
- Indexed parameters for efficient filtering
- Complete information in event data
- Consistent event naming conventions
- Off-chain indexing considerations

## Migration Path

### Immediate (Phase 1-2)
1. Deploy registry on all chains
2. Update contract deployments to include registry
3. Gradually migrate existing relationships

### Medium Term (Phase 3-4)
1. Enhance registry with advanced features
2. Complete migration of all deployments
3. Deprecate old setter methods

### Long Term (Phase 5)
1. Advanced cross-chain features
2. Full governance integration
3. Analytics and monitoring platform

## Success Criteria
- [ ] All new deployments use registry system
- [ ] Existing deployments successfully migrated
- [ ] No breaking changes to existing functionality
- [ ] Improved operational efficiency
- [ ] Enhanced security posture
- [ ] Comprehensive monitoring capabilities

## Files to Create/Modify

### New Files
- `packages/core-contracts/src/interfaces/ICrossChainRegistry.sol`
- `packages/core-contracts/src/contracts/CrossChainRegistry.sol`
- `packages/deployment/ignition/modules/CrossChainRegistryModule.ts`
- `packages/core-contracts/test/CrossChainRegistry.t.sol`

### Modified Files
- `packages/core-contracts/src/contracts/arks/CrossChainArk.sol`
- `packages/core-contracts/src/contracts/FleetProxy.sol`
- `packages/deployment/scripts/arks/deploy-cross-chain-ark.ts`
- `packages/deployment/scripts/arks/deploy-fleet-proxy.ts`
- `packages/deployment/ignition/modules/arks/cross-chain-ark.ts`
- `packages/deployment/ignition/modules/arks/fleet-proxy.ts`

## Naming Suggestions
- Rename `CrossChainRegistry.sol` to `ArkProxyRegistry.sol` for clarity
- Consider `CrossChainRelationshipRegistry.sol` for full descriptiveness
- Alternative: `BridgeRegistry.sol` to emphasize the bridging aspect

This registry will provide a much more robust and maintainable system for managing cross-chain relationships while maintaining backward compatibility during the migration period.