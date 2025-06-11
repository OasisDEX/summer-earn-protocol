# Cross-Chain Configuration Files

This directory contains **deployment coordination** files for cross-chain fleet deployments. These files are used by deployment scripts to track deployment progress and coordinate between source and destination chains.

## 🎯 **Purpose**

These configuration files serve a **different purpose** than the CrossChainRegistry contract:

- **Cross-Chain Configs** (this directory): Deployment tooling and coordination
- **CrossChainRegistry** (on-chain): Runtime protocol functionality

## 📁 **File Structure (Simplified)**

Each fleet has one configuration file with a **simplified but functional** structure:
```json
{
  "fleetName": "FleetName",
  "sourceChainId": 1,
  "destinations": [
    {
      "chainId": 42161,
      "name": "arbitrum",
      "protocols": [
        {
          "protocol": "summerfi",
          "fleetProxyAddress": "0x...",      // Set when FleetProxy is deployed
          "crossChainArkAddress": "0x..."   // Set when CrossChainArk is deployed
        }
      ]
    }
  ]
}
```

## ✨ **Key Simplifications**

**Removed complexity:**
- ❌ Asset metadata (gets from chain config instead)
- ❌ Deployment timestamps, gas costs, block numbers
- ❌ Verification status tracking
- ❌ Complex nested structures

**Kept essentials:**
- ✅ Protocol identification (needed for deployment scripts)
- ✅ Cross-chain relationship tracking
- ✅ Multiple protocols per chain support

## 🔄 **Deployment Flow**

1. **Create config file** when starting cross-chain deployment
2. **Deploy FleetProxy** on destination chain → updates `fleetProxyAddress`
3. **Deploy CrossChainArk** on source chain → updates `crossChainArkAddress`
4. **Register relationship** in CrossChainRegistry (on-chain)
5. **Link contracts** via governance or setter functions

## 🆚 **Config vs Registry**

| Aspect | Cross-Chain Config | CrossChainRegistry |
|--------|-------------------|-------------------|
| **Purpose** | Deployment coordination | Runtime protocol queries |
| **Storage** | Local JSON files | On-chain contract |
| **Lifetime** | Deployment phase | Permanent protocol state |
| **Access** | Deployment scripts | Smart contracts & dApps |
| **Complexity** | Simplified, essential data | Full validation & relationships |

## 🔧 **Usage**

The deployment scripts work with this simplified structure:

```typescript
// Save deployment address (simplified)
saveCrossChainConfig('MyFleet', {
  chainId: 42161,
  protocol: 'summerfi',
  fleetProxyAddress: '0x...'
})

// Load for deployment coordination
const config = loadCrossChainConfig('MyFleet')
const protocolConfig = findProtocolConfig(config, 42161, 'summerfi')
```

## 🚀 **Next Steps**

After both contracts are deployed:
1. Register the relationship in CrossChainRegistry
2. Configure contracts to point to each other  
3. Deploy via governance proposal

## 🧠 **Design Philosophy**

This balanced approach:
- **Removes deployment metadata** (gas, timestamps) → unnecessary complexity
- **Keeps protocol structure** → needed by existing deployment scripts
- **Simplifies data model** → easier to understand and maintain
- **Maintains compatibility** → existing scripts still work 