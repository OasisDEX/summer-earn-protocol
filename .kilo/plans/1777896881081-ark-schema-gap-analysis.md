# ArkConfig Schema Analysis - Gap Report

**File:** `packages/deployment/scripts/helpers/zod-schemas.ts`
**Date:** 2026-05-04

---

## 1. Current State

The `ArkConfigSchema` is already implemented as a discriminated union with:
- **17 specific ArkType schemas** with required params
- **1 fallback** using `BaseArkParamsSchema` for unlisted types

### ArkType Enum vs Implemented Schemas

| ArkType | In Discriminated Union? | Schema Used |
|---------|-------------------------|-------------|
| CrossChainArk | ✓ | CrossChainArkParamsSchema |
| ERC4626Ark | ✓ | ERC4626ArkParamsSchema |
| PendleLPArk | ✓ | PendleLPArkParamsSchema |
| PendlePTArk | ✓ | PendlePTArkParamsSchema |
| PendlePtOracleArk | ✓ | PendleLPArkParamsSchema (reused) |
| MorphoArk | ✓ | MorphoArkParamsSchema |
| MorphoVaultArk | ✓ | MorphoArkParamsSchema (reused) |
| MorphoV2VaultArk | ✓ | MorphoArkParamsSchema (reused) |
| SiloArk | ✓ | SiloArkParamsSchema |
| SiloArkV2 | ✓ | SiloArkParamsSchema (reused) |
| SiloManagedVaultArk | ✓ | SiloArkParamsSchema (reused) |
| AeraArk | ✓ | AeraArkParamsSchema |
| WisdomTreeArk | ✓ | WisdomTreeArkParamsSchema |
| SkyRewardsArk | ✓ | SkyRewardsArkParamsSchema |
| ArmArk | ✓ | ArmArkParamsSchema |
| SiUSDArk | ✓ | SiUSDArkParamsSchema |
| PsmLiteERC4626Ark | ✓ | PsmLiteERC4626ArkParamsSchema |
| Psm3ERC4626Ark | ✓ | Psm3ERC4626ArkParamsSchema |
| AaveV3Ark | fallback only | BaseArkParamsSchema |
| SparkArk | fallback only | BaseArkParamsSchema |
| CompoundV3Ark | fallback only | BaseArkParamsSchema |
| SkyUsdsArk | fallback only | BaseArkParamsSchema |
| SkyUsdsPsm3Ark | fallback only | BaseArkParamsSchema |
| MoonwellArk | fallback only | BaseArkParamsSchema |
| SyrupArk | fallback only | BaseArkParamsSchema |
| OriginETHArk | fallback only | BaseArkParamsSchema |
| FluidLiteArk | fallback only | BaseArkParamsSchema |
| StargateV2PoolArk | fallback only | BaseArkParamsSchema |
| FluidFTokenArk | fallback only | BaseArkParamsSchema |
| HyperlendArk | fallback only | BaseArkParamsSchema |
| HypurrArk | fallback only | BaseArkParamsSchema |
| MapleInstitutionalArk | fallback only | BaseArkParamsSchema |
| UpshiftArk | fallback only | BaseArkParamsSchema |
| OriginUSDArk | fallback only | BaseArkParamsSchema |

**Count:** 18 explicit + 16 fallback = 34 total (3 more than enum's 31 - discrepancy in count)

---

## 2. Issues Identified

### 2.1 Schema Reuse Without Validation Difference

The discriminated union reuses schemas for multiple ArkTypes:
- `PendleLPArkParamsSchema` used for both `PendleLPArk` and `PendlePtOracleArk`
- `MorphoArkParamsSchema` used for `MorphoArk`, `MorphoVaultArk`, `MorphoV2VaultArk`
- `SiloArkParamsSchema` used for `SiloArk`, `SiloArkV2`, `SiloManagedVaultArk`

**Issue:** This is efficient but may not capture subtle differences between these ArkTypes. Each should be verified that the params actually work for all use cases.

### 2.2 Fallback vs Specific Schema Strategy

Some complex ArkTypes like `CrossChainArk` have required `targetChainId` in their schema, but when falling back to `BaseArkParamsSchema`, this validation is lost.

**Current CrossChainArkParamsSchema:**
```typescript
export const CrossChainArkParamsSchema = BaseArkParamsSchema
// NO extensions! Just aliases BaseArkParamsSchema
```

**Problem:** `targetChainId` is `z.string().optional()` in `BaseArkParamsSchema`, but `CrossChainArk` requires it. The discriminated union correctly requires `targetChainId` for `CrossChainArk` type matching, but the fallback doesn't validate it.

### 2.3 Missing ArkTypes in Implementation

Comparing ArkType enum (31 values) with what's handled in `ark-deployment.ts` (36 switch cases for 34 types - there's a discrepancy):

**From ark-deployment.ts switch:**
- FluidLiteArk - handled
- AaveV3Ark - handled
- HyperlendArk - handled
- HypurrArk - handled
- SparkArk - handled
- CompoundV3Ark - handled
- ERC4626Ark - handled
- UpshiftArk - handled
- FluidFTokenArk - handled
- MorphoArk - handled
- MorphoVaultArk - handled
- MorphoV2VaultArk - handled
- PendleLPArk - handled
- SkyUsdsArk - handled
- SkyUsdsPsm3Ark - handled
- MoonwellArk - handled
- SyrupArk - handled
- MapleInstitutionalArk - handled
- SkyRewardsArk - handled
- SiloArk - handled
- CrossChainArk - handled
- SiloArkV2 - handled
- OriginUSDArk - handled
- OriginETHArk - handled
- ArmArk - handled
- SiloManagedVaultArk - handled
- AeraArk - handled
- StargateV2PoolArk - handled
- SiUSDArk - handled
- PsmLiteERC4626Ark - handled
- Psm3ERC4626Ark - handled
- WisdomTreeArk - handled

**ArkType enum has these NOT in switch (but are in fallback):**
- (none found - all 31 appear to be handled)

### 2.4 Schema-Code Synchronization Issue

**CrossChainArk implementation in ark-deployment.ts (lines 305-353):**
```typescript
case ArkType.CrossChainArk: {
  const targetChainId = Number(arkConfig.params.targetChainId)
  const targetProtocol = arkConfig.params.protocol

  if (!targetChainId || !targetProtocol) {
    throw new Error('CrossChainArk requires targetChainId and protocol parameters')
  }
```

**But in zod-schemas.ts, CrossChainArkParamsSchema is just an alias:**
```typescript
export const CrossChainArkParamsSchema = BaseArkParamsSchema
// Same as BaseArkParamsSchema - NO REQUIRED targetChainId
```

**Fix needed:** CrossChainArkParamsSchema should extend BaseArkParamsSchema and make targetChainId REQUIRED:
```typescript
export const CrossChainArkParamsSchema = BaseArkParamsSchema.extend({
  targetChainId: z.string().min(1),  // REQUIRED
})
```

### 2.5 ArkConfig Type Export Conflict

In `config-types.ts`:
```typescript
export type ArkConfig = ArkConfigType  // Line 339
```

But in `zod-schemas.ts`:
```typescript
export type ArkConfig = z.infer<typeof ArkConfigSchema>  // Line 263
```

**Problem:** `ArkConfig` is exported from BOTH files with DIFFERENT definitions!

---

## 3. ArkConfig Type Definition Sources

### config-types.ts (line 339)
```typescript
export type ArkConfig = ArkConfigType
// But ArkConfigType is NOT defined in this file - likely removed/moved?
```

### zod-schemas.ts (line 263)
```typescript
export type ArkConfig = z.infer<typeof ArkConfigSchema>
// This is the ACTUAL working type
```

### config-types.ts (line 334-349)
```typescript
interface ArkConfigType {
  type: ArkType
  params: {
    asset: string
    protocol: string
    vaultName?: string
    fundName?: string
    // ... all optional params
    version: number
  }
}
```

**Finding:** The old `ArkConfigType` interface in config-types.ts is the one used by `ark-deployment.ts` line 64-67, but the Zod-derived `ArkConfig` is what gets exported and used for validation.

---

## 4. Required Fixes

### 4.1 CrossChainArkParamsSchema (CRITICAL)
Make `targetChainId` required for CrossChainArk type safety.

```typescript
export const CrossChainArkParamsSchema = BaseArkParamsSchema.extend({
  targetChainId: z.string().min(1),  // Override to REQUIRED
})
```

### 4.2 Remove Duplicate ArkConfig Export
Either:
- Remove `export type ArkConfig = ArkConfigType` from config-types.ts (preferred - use Zod-derived)
- Or import ArkConfig from zod-schemas.ts in config-types.ts

### 4.3 Add Specific Schemas for Complex ArkTypes
These ArkTypes likely need specific params beyond BaseArkParamsSchema:
- **CrossChainArk** - targetChainId required (see 4.1)
- **UpshiftArk** - may need specific vaultName handling
- **FluidLiteArk** - has depositCap, maxRebalanceOutflow, maxRebalanceInflow as primary params

### 4.4 Validate Schema Consistency with Implementation
Run a comparison between:
- What each ArkType's deployment function expects
- What the Zod schema allows/provides

---

## 6. Files Requiring Changes

| File | Changes |
|------|---------|
| `scripts/helpers/zod-schemas.ts` | Fix CrossChainArkParamsSchema, add missing specific schemas, remove duplicate ArkConfig export or reconcile with config-types.ts |
| `types/config-types.ts` | Remove or rename conflicting `ArkConfig` type definition, use Zod-derived type |

---

## 7. Implementation Plan (Comprehensive)

### Phase 1: Fix CrossChainArkParamsSchema

**File:** `scripts/helpers/zod-schemas.ts`

```typescript
// BEFORE (broken):
export const CrossChainArkParamsSchema = BaseArkParamsSchema

// AFTER (correct):
export const CrossChainArkParamsSchema = BaseArkParamsSchema.extend({
  targetChainId: z.string().min(1),  // Override to REQUIRED
  protocol: z.string().min(1),        // Ensure required
})
```

### Phase 2: Add Specific Schemas for Complex ArkTypes

**File:** `scripts/helpers/zod-schemas.ts`

Add schemas for ArkTypes that have specific required params beyond BaseArkParamsSchema:

```typescript
// FluidLiteArk specific params
export const FluidLiteArkParamsSchema = BaseArkParamsSchema.extend({
  depositCap: z.string().min(1),        // REQUIRED - deposit cap is critical
  maxRebalanceOutflow: z.string().optional(),
  maxRebalanceInflow: z.string().optional(),
})

// OriginETHArk specific params
export const OriginETHArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().optional(),
  // originETH has specific vault handling
})

// HyperlendArk, HypurrArk - review if they need specific schemas
```

### Phase 3: Fix Duplicate ArkConfig Export

**Option A (Preferred):** Remove old interface from config-types.ts

**File:** `types/config-types.ts`
```typescript
// REMOVE lines 334-349 (ArkConfigType interface)
// REMOVE line 339 (export type ArkConfig = ArkConfigType)
// IMPORTS from zod-schemas.ts already use the correct type
```

**Option B:** Export Zod-derived type from config-types.ts

**File:** `types/config-types.ts`
```typescript
import { ArkConfig as ArkConfigFromZod } from '../scripts/helpers/zod-schemas'
export type ArkConfig = ArkConfigFromZod
// Remove local ArkConfigType definition
```

### Phase 4: Verify All ArkTypes

**File:** `scripts/helpers/zod-schemas.ts`

Ensure every ArkType in the enum is handled:
1. AaveV3Ark - fallback OK
2. SparkArk - fallback OK
3. CompoundV3Ark - fallback OK
4. CrossChainArk - **NEEDS FIX** (Phase 1)
5. ERC4626Ark - explicit OK
6. MorphoArk - explicit OK
7. MorphoVaultArk - explicit OK
8. MorphoV2VaultArk - explicit OK
9. PendleLPArk - explicit OK
10. PendlePTArk - explicit OK
11. PendlePtOracleArk - explicit OK
12. SkyUsdsArk - fallback OK
13. SkyUsdsPsm3Ark - fallback OK
14. MoonwellArk - fallback OK
15. SyrupArk - fallback OK
16. SkyRewardsArk - explicit OK
17. SiloArk - explicit OK
18. SiloArkV2 - explicit OK
19. SiloManagedVaultArk - explicit OK
20. OriginETHArk - fallback - **CHECK: needs specific?**
21. ArmArk - explicit OK
22. FluidLiteArk - fallback - **CHECK: needs specific?**
23. AeraArk - explicit OK
24. StargateV2PoolArk - fallback OK
25. SiUSDArk - explicit OK
26. FluidFTokenArk - fallback OK
27. PsmLiteERC4626Ark - explicit OK
28. Psm3ERC4626Ark - explicit OK
29. HyperlendArk - fallback OK
30. HypurrArk - fallback OK
31. WisdomTreeArk - explicit OK
32. MorphoV2VaultArk - explicit (already covered)
33. MapleInstitutionalArk - fallback OK
34. UpshiftArk - explicit OK (ERC4626Ark schema used)
35. OriginUSDArk - fallback OK

### Phase 5: Remove Redundant Schema Reuse

Currently `PendleLPArkParamsSchema` is used for both `PendlePTArk` and `PendlePtOracleArk`. Verify these are truly equivalent:
- If not, create separate schemas
- If yes, add a comment explaining why they're shared

---

## 8. Verification Plan

1. Run `tsc --noEmit` to ensure no type conflicts after changes
2. Create test validation: pass invalid config (missing required fields) and verify Zod rejects it
3. Check `ark-deployment.ts` uses same params as schema defines
4. Confirm `CrossChainArk` targetChainId is validated at parse time, not just runtime throw