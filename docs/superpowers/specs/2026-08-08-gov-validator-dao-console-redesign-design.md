# Design Specification: DAO Console Redesign for Summer Earn Gov Validator

**Date:** 2026-08-08  
**Status:** Approved  
**Target Package:** `packages/summer-earn-gov-validator`  
**Reference Design:** `.resources/design/Summer DAO Console.dc.html`, `Summer Design System.dc.html`

---

## 1. Executive Summary & Goals

This specification details the end-to-end design transformation of the `summer-earn-gov-validator` Next.js application to adopt the new **Summer DAO Console** design system from `.resources/design/`. 

The redesign introduces:
- A standardized CSS variable token scale supporting both Dark Mode (default) and Light Mode.
- Monospaced numeric and data formatting (`JetBrains Mono`) for hex addresses, timestamps, proposal IDs, percentages, and vote metrics.
- Refactored sticky top navigation header and sub-navigation tabs.
- Completely updated components across all application views: Proposals, Proposal Details, Treasury, Delegates, Create Proposal, and Cross-Chain Simulation Center.

---

## 2. Design System Tokens & Theme Support

### 2.1 CSS Color Variables & Design Ramp (`src/styles/globals.scss`)

The `:root` element will define dark mode tokens by default, and `[data-theme="light"]` will override color variables for light mode.

```scss
:root {
  --bg: #141414;
  --surface: #1C1C1C;
  --surface2: #232323;
  --surface3: #2B2B2B;
  --field: #181818;
  --line: #2E2E2E;
  --line2: #3D3D3D;
  --fg: #FFFBFD;
  --fg2: #BAB8B9;
  --fg3: #777576;

  --pink: #FF49A4;
  --pinkHi: #FF80BF;
  --violet: #B049FF;
  --grad: linear-gradient(90deg, #FF49A4, #B049FF);

  --ok: #69DF31;
  --warn: #F9A601;
  --crit: #FF5739;
  --info: #5C82FF;

  --okBg: rgba(105, 223, 49, 0.13);
  --warnBg: rgba(249, 166, 1, 0.13);
  --critBg: rgba(255, 87, 57, 0.13);
  --pinkBg: rgba(255, 73, 164, 0.13);
  --infoBg: rgba(92, 130, 255, 0.15);
  --tint: rgba(255, 255, 255, 0.045);
}

[data-theme="light"] {
  --bg: #F6F3F4;
  --surface: #FFFFFF;
  --surface2: #FBF9FA;
  --surface3: #F1EDEF;
  --field: #FFFFFF;
  --line: #E7E2E4;
  --line2: #D6D0D3;
  --fg: #191517;
  --fg2: #6B6568;
  --fg3: #948E91;

  --pink: #D6157F;
  --pinkHi: #B60C69;
  --violet: #8B24E0;
  --grad: linear-gradient(90deg, #D6157F, #8B24E0);

  --ok: #3E8F16;
  --warn: #9A6600;
  --crit: #CE3419;
  --info: #2A4ED6;

  --okBg: rgba(62, 143, 22, 0.1);
  --warnBg: rgba(154, 102, 0, 0.1);
  --critBg: rgba(206, 52, 25, 0.1);
  --pinkBg: rgba(214, 21, 127, 0.09);
  --infoBg: rgba(42, 78, 214, 0.1);
  --tint: rgba(17, 15, 16, 0.035);
}
```

### 2.2 Typography Scale
- **Prose & Body:** `Inter, system-ui, sans-serif`
- **Data & Numbers:** `'JetBrains Mono', monospace` (loaded via Google Fonts) for hashes, addresses, SIP tags, date/timestamps, voting power values, and gas numbers.

---

## 3. Layout Shell & Navigation

### 3.1 Header & Top Sub-Nav (`src/components/Header.tsx`, `TopNavBar.tsx`)
- **Sticky Header:** Positioned at `top: 0`, `z-index: 20` with `var(--surface)` background and `var(--line)` bottom border.
- **Header Elements:**
  - Brand identity: 26px gradient dot + "Lazy Summer DAO" title (`font-weight: 600`).
  - Actions: Theme toggle (`☀️`/`🌙`), "New proposal" shortcut, and "Connect wallet" pill button with brand gradient.
- **Top Sub-Nav Tabs:**
  - Clean horizontal tab bar for routing: `Proposals`, `Treasury`, `Delegates`, `Create proposal`, `Cross-chain`.
  - Active tab indicated by `border-bottom: 2px solid var(--pink)` and `--fg` color.

---

## 4. Detailed Component Specifications by View

### 4.1 Proposals View (`src/app/proposals`, `ProposalsList.tsx`, `ProposalFilter.tsx`)
- **Page Title:** `Proposals` (26px, weight 600, tracking -0.03em) + sub-description.
- **Status Filter Bar:** Pill buttons (`All`, `Active`, `Pending`, `Succeeded`, `Executed`, `Queued`, `Defeated`, `Canceled`) using semantic background/text variables.
- **Network Dropdown:** Network selector for Base, Mainnet, Arbitrum, Sonic, Hyperliquid.
- **Proposal Cards:**
  - Header: Monospaced SIP tag (`SIP4.3`), status badge (`Active`/`Pending`/`Executed`), network badge, and relative date.
  - Body: 2-column layout. Left: Title, summary paragraph, "View details" button. Right: Quorum meter bar + For/Against/Abstain breakdown bars with monospaced percentages.

### 4.2 Proposal Detail View (`src/app/proposal/[id]`, `ProposalExecutionDetails.tsx`, `ProposalVotingInfo.tsx`)
- **Main Panel:** SIP Title, badge metadata, and full rendered markdown proposal description.
- **Phase Timeline Indicator:** Step-by-step state tracker (Pending → Active → Succeeded → Queued → Executed).
- **Voting Action Panel:** User voting power (stSUMR) display, vote submission options, and live voting modal.
- **Proposed Actions List:** Target contract address (`JetBrains Mono`), chain tag, decoded signature, function selector hash, parameter values table, and calldata copy action.

### 4.3 Treasury View (`src/app/treasury`, `TreasuryView.tsx`, `TreasuryList.tsx`)
- **KPI Summary Grid:** Cards for Total Treasury Value, SUMR Price, and Liquid Reserves set in 24px `JetBrains Mono`.
- **Top Holdings Panel:** Aggregated token holdings showing token logo mark, symbol, USD value, balance, and percentage share progress bar (`var(--grad)` fill).
- **Wallet Sections:** Grouped wallet breakdowns (*Main Treasury*, *Arcadia PoL*, *Aerodrome Multisig*, *Guardians*) with token balances and chain indicators.

### 4.4 Delegates View (`src/app/delegates`, `DelegatesList.tsx`)
- **Header & Stats:** Search input + delegate stats (Total stSUMR Staked, Delegated Weight, Active Delegates).
- **Delegate Cards Grid:** Avatar mark, Name, shortened address (`JetBrains Mono`), Rank badge (`#1`), 3-line bio, Voting Power, Delegators count, voting weight share bar, and "Delegate votes" pill action.

### 4.5 Create Proposal & Simulation Center (`src/app/create-proposal`, `src/app/cross-chain`, `Form.tsx`, `SimulationCenter`)
- **Header & Toolbar:** Category tag `MULTI-CHAIN GOVERNANCE`, title, Import/Export JSON buttons, Simulation trigger, Skip Simulation toggle, and Submit button.
- **Action Builder:** Chain selector, Target address, Method selector, dynamic parameter inputs with `--pink` type tags, selector hash computation.
- **Right Column (Simulation Center):** On-chain eligibility checks, LayerZero satellite executor gas limit inputs, and per-chain simulation status cards (*Idle*, *Pending*, *Done* with gas used in `JetBrains Mono` + execution trace trigger).

---

## 5. Testing & Verification Strategy

1. **Visual & Theme Verification:** Validate all views in both Dark and Light modes (`data-theme="light"` / `dark`) for proper color contrast and CSS variable resolution.
2. **Monospace & Alignment Checks:** Verify that all numbers, hashes, percentages, dates, and addresses render in `JetBrains Mono`.
3. **Responsive Testing:** Verify 2-column grid collapse on mobile screens (`@media (max-width: 760px)`).
4. **Integration & Build Checks:** Ensure `pnpm --filter summer-earn-gov-validator build` succeeds without linting or compilation errors.
