# Summer Earn Interface — Design Brief

Design document for a new modern look across the entire application.

---

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Styling:** Tailwind CSS v3.4
- **Font:** Inter (Google Fonts) — set in `layout.tsx`
- **Charts:** Recharts
- **Toast notifications:** Sonner
- **Wallet:** Reown AppKit (wagmi)
- **No shadcn/ui or Radix** — custom components only

---

## Current Design System (Tailwind)

### Custom Theme (tailwind.config.js)

```js
colors: {
  charcoal: {
    900: '#0f1115',  // Page background
    800: '#141821',  // Card/header background
    700: '#1b2130',  // Inputs, secondary surfaces
  },
  magenta: {
    500: '#ff2d8f',
    600: '#e02682',
    700: '#c01f71',
  },
  violet: {
    400: '#9b7bff',
    500: '#7c5cff',
  },
}
boxShadow: {
  glow: '0 0 0 2px rgba(255,45,143,0.35)',
  card: '0 0 0 1px rgba(255,255,255,0.06)',
}
borderRadius: { xl: '14px' }
fontFamily: { sans: ['Inter', ...] }
```

### CSS Variables (globals.css)

- `--background` / `--foreground` — light/dark system
- `@theme inline` — Tailwind v4-style integration

### Common Patterns

- Dark theme dominant: `bg-black`, `bg-gray-900`, `bg-charcoal-900`
- Cards: `bg-charcoal-800/70`, `border border-white/10`, `shadow-card`, `backdrop-blur`
- Accents: blue (links, focus), magenta (deposit), red (withdraw), green (success)
- Mono font for addresses
- Loading: `animate-pulse` skeletons

---

## Routes & Views

| Route | Purpose |
|-------|---------|
| `/` | **Home** — Chain selector, Quick Actions links, Fleet cards grid |
| `/fleet/[chainId]/[address]` | **Fleet Detail** — Fleet info, user position, deposit/withdraw tabs, staking, arks list, rebalance form, fleet management |
| `/access-manager/[chainId]` | **Protocol Access Manager** — Role selection, fleet/ark selector, grant/revoke roles |
| `/roles/[chainId]` | **Roles Viewer** — Table of all roles (search, filter, sort), links to block explorer |
| `/interest-rates` | **Interest Rates** — Chain/product/interval selector, line chart |
| `/vault-apr` | **Vault APR** — Chain filter, vault selector, APR charts (weekly/daily/hourly) |
| `/institutions` | **Institutions** — Chain + institution selector, roles panel, whitelist manager |
| `/rewards` | **Rewards Dashboard** — Stats (fleets, arks), chain selector, FleetRewards accordion |
| `/vesting/[chainId]` | **Vesting** — Address lookup, vesting wallet details, goals, claim/release UI |
| `/vesting/[chainId]/batch` | **Vesting Batch** — Server-rendered table of vesting snapshots, sortable |
| `/vesting-staking/[chainId]` | **Vesting Staking** — Vesting wallet + xSUMMER staking flow |
| `/summer-staking/[chainId]` | **Summer Staking** — Stake/unstake SUMMER, lockup buckets, vesting integration |
| `/intent-system` | **Intent System** — Create/solve intents, solver bond, intent list |
| `/interest-rates` | **Interest Rates** — Chart + product selection |

---

## Global Layout

- **Header:** Logo "Summer Earn Protocol", version badge, EnvironmentSelector, ConnectButton
- **Main:** `max-w-9xl` container, `px-4 sm:px-6 lg:px-8 py-8`
- **Background:** `min-h-screen bg-charcoal-900`

---

## Components Inventory

### Layout & Navigation

| Component | Location | Purpose |
|-----------|----------|---------|
| `ConnectButton` | `components/ConnectButton.tsx` | Wallet connect/disconnect, truncated address |
| `EnvironmentSelector` | `components/EnvironmentSelector.tsx` | Production/staging toggle |
| `ChainSelector` | `components/ChainSelector.tsx` | Chain dropdown (Ethereum, Arbitrum, Base, etc.) |

### Fleet & DeFi

| Component | Location | Purpose |
|-----------|----------|---------|
| `FleetCard` | `components/FleetCard.tsx` | Card: fleet name, TVL, withdrawable %, deposit/withdraw inputs, link to detail |
| `FleetSelector` | `components/FleetSelector.tsx` | Dropdown to pick a fleet (used in Access Manager) |
| `Ark` | `components/Ark.tsx` | Ark details (rewards, actions) within fleet page |
| `AmountInput` | `components/AmountInput.tsx` | Numeric input with Max/Max Uint, balance display |
| `DepositWithdrawTabs` | `components/DepositWithdrawTabs.tsx` | Tabbed deposit/withdraw with amount input |
| `RebalanceForm` | `components/RebalanceForm.tsx` | Multi-row rebalance (from ark → to ark, amount) |
| `FleetManagementForm` | `components/FleetManagementForm.tsx` | Fleet config (deposit cap, buffer, ark limits) |
| `ArkManagementForm` | `components/ArkManagementForm.tsx` | Ark config (deposit cap, limits) |
| `StakingSection` | `components/StakingSection.tsx` | Stake fleet tokens for rewards |
| `StakeAfterDepositPrompt` | `components/StakeAfterDepositPrompt.tsx` | Prompt to stake after depositing |
| `AuctionConfigModal` | `components/AuctionConfigModal.tsx` | Modal for ark auction config |

### Rewards & Charts

| Component | Location | Purpose |
|-----------|----------|---------|
| `FleetRewards` | `components/FleetRewards.tsx` | Accordion: fleet → arks → token balances, claimable rewards |
| `InterestRateChart` | `components/InterestRateChart.tsx` | Recharts line chart for interest rates |
| `VaultAprChart` | `components/VaultAprChart.tsx` | APR chart for vaults |
| `RangeSelector` | `components/RangeSelector.tsx` | Time range buttons (24h, 7d, etc.) |

### Access & Roles

| Component | Location | Purpose |
|-----------|----------|---------|
| `RoleManager` | `components/RoleManager.tsx` | Grant/revoke roles, address input |
| `InstitutionSelector` | `components/InstitutionSelector.tsx` | Institution dropdown |
| `InstitutionRolesPanel` | `components/InstitutionRolesPanel.tsx` | Roles list for selected institution |
| `WhitelistManager` | `components/WhitelistManager.tsx` | Vault whitelist management |
| `AdmiralsWhitelistToggle` | `components/AdmiralsWhitelistToggle.tsx` | Toggle for whitelist |
| `ContractCard` | `components/ContractCard.tsx` | Card showing contract address and link |

### Intent System (Modals)

| Component | Location | Purpose |
|-----------|----------|---------|
| `CreateIntentModal` | `components/modals/CreateIntentModal.tsx` | Create new intent |
| `SolveIntentModal` | `components/modals/SolveIntentModal.tsx` | Solve an intent |
| `CreateBondModal` | `components/modals/CreateBondModal.tsx` | Create solver bond |
| `SetPriceModal` | `components/modals/SetPriceModal.tsx` | Set oracle price |
| `AdminModal` | `components/modals/AdminModal.tsx` | Admin actions |

### Intent System (Inline)

| Component | Location | Purpose |
|-----------|----------|---------|
| `SolverInfo` | `components/SolverInfo.tsx` | Solver bond amount, fund bond button |

### Vesting

| Component | Location | Purpose |
|-----------|----------|---------|
| `VestingBatchTable` | `components/VestingBatchTable.tsx` | Sortable table of vesting snapshots |
| `RefreshButton` | `components/RefreshButton.tsx` | Refetch + last updated time |

### Utilities

| Component | Location | Purpose |
|-----------|----------|---------|
| `Skeleton` | `components/Skeleton.tsx` | Loading placeholder |
| `DebugStakingInfo` | `components/DebugStakingInfo.tsx` | Dev-only staking debug (commented out) |

---

## UI Patterns to Design

### Form Elements

- Select/dropdown (chain, product, institution, fleet, ark)
- Text input (amount, address, search)
- Buttons: primary (magenta), secondary (gray), destructive (red), link-style (blue)
- Tabs (deposit/withdraw)
- Checkbox/toggle

### Data Display

- Info cards (label + value)
- Stats grid (e.g. Active Fleets, Total ARKs)
- Tables (sortable, filterable)
- Accordions
- Address + block explorer link
- Token amounts with symbol
- Progress/percentage bars

### Modals

- Create Intent, Solve Intent
- Create Bond, Set Price
- Admin, Auction Config
- Overlay + close button pattern

### States

- Loading (skeleton, spinners)
- Empty state (“No arks found”, “No roles”)
- Error (message + retry)
- Success (toast via Sonner)

### Responsive

- Mobile-first; `sm:`, `md:`, `lg:` breakpoints used
- Grid: `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`
- Flex for layout, spacing `gap-4`, `space-y-6`

---

## Chains Supported

- Ethereum (1)
- Arbitrum (42161)
- Base (8453)
- Sonic (146)
- (Testnet 999)

---

## Suggested Deliverables for Designer

1. **Design system** — Color palette, typography, spacing, shadows, border radius
2. **Component library** — Buttons, inputs, cards, modals, tables
3. **Page mockups** — Home, Fleet Detail, Access Manager, Vesting, Rewards, Intent System
4. **Responsive specs** — Mobile, tablet, desktop
5. **States** — Default, hover, focus, disabled, loading, error
6. **Figma/Sketch/XD file** — Shareable with dev for implementation

---

## File Structure Reference

```
src/
├── app/
│   ├── layout.tsx              # Root layout (header, main)
│   ├── page.tsx                # Home
│   ├── globals.css
│   ├── access-manager/[chainId]/page.tsx
│   ├── roles/[chainId]/page.tsx
│   ├── fleet/[chainId]/[address]/page.tsx
│   ├── interest-rates/page.tsx
│   ├── vault-apr/page.tsx
│   ├── institutions/page.tsx
│   ├── rewards/page.tsx
│   ├── intent-system/page.tsx
│   ├── vesting/[chainId]/page.tsx
│   ├── vesting/[chainId]/batch/page.tsx
│   ├── vesting-staking/[chainId]/page.tsx
│   └── summer-staking/[chainId]/page.tsx
└── components/
    ├── ConnectButton.tsx
    ├── EnvironmentSelector.tsx
    ├── ChainSelector.tsx
    ├── FleetCard.tsx
    ├── FleetSelector.tsx
    ├── FleetManagementForm.tsx
    ├── FleetRewards.tsx
    ├── Ark.tsx
    ├── ArkManagementForm.tsx
    ├── RebalanceForm.tsx
    ├── DepositWithdrawTabs.tsx
    ├── AmountInput.tsx
    ├── StakingSection.tsx
    ├── StakeAfterDepositPrompt.tsx
    ├── AuctionConfigModal.tsx
    ├── RoleManager.tsx
    ├── InstitutionSelector.tsx
    ├── InstitutionRolesPanel.tsx
    ├── WhitelistManager.tsx
    ├── AdmiralsWhitelistToggle.tsx
    ├── ContractCard.tsx
    ├── InterestRateChart.tsx
    ├── VaultAprChart.tsx
    ├── RangeSelector.tsx
    ├── VestingBatchTable.tsx
    ├── RefreshButton.tsx
    ├── Skeleton.tsx
    ├── SolverInfo.tsx
    ├── DebugStakingInfo.tsx
    └── modals/
        ├── CreateIntentModal.tsx
        ├── SolveIntentModal.tsx
        ├── CreateBondModal.tsx
        ├── SetPriceModal.tsx
        └── AdminModal.tsx
```
