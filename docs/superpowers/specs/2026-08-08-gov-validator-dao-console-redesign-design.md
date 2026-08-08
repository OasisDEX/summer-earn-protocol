# Design Specification: DAO Console Redesign for Summer Earn Gov Validator

**Date:** 2026-08-08  
**Status:** Revision 2 (Feedback Applied)  
**Target Package:** `@summerfi/summer-earn-gov-validator`  
**Reference Design:** `.resources/design/Summer DAO Console.dc.html`, `Summer Design System.dc.html`

---

## 1. Executive Summary & Goals

This specification details the end-to-end design transformation of the `@summerfi/summer-earn-gov-validator` Next.js application to adopt the **Summer DAO Console** design system from `.resources/design/`. 

The redesign introduces:
- A standardized CSS variable token scale supporting both Dark Mode (default) and Light Mode.
- Monospaced numeric and data formatting (`JetBrains Mono`) for hex addresses, timestamps, proposal IDs, percentages, and vote metrics.
- Refactored header (`Header.tsx`, `TopNavBar.tsx`), navigation rail (`SideNavBar.tsx`), mobile navigation (`BottomNavBar.tsx`), and sub-navigation tabs across all v1 and current routes.
- Completely updated components across all application views: Proposals (v1 & current), Proposal Details (v1 & current), Treasury, Delegates, Create Proposal, and Simulation components.

---

## 2. Design System Tokens & Theme Support

### 2.1 CSS Color Variables & Design Ramp (`src/styles/globals.scss`)

The `:root` element defines dark mode tokens by default, and `[data-theme="light"]` overrides color variables for light mode.

> [!NOTE]
> The light palette below is derived for matched contrast and requires brand sign-off prior to production deployment.

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
- **Data & Numbers:** `'JetBrains Mono', monospace` (loaded via Google Fonts) for hex hashes, addresses, SIP tags, timestamps, voting power metrics, percentages, and gas numbers.

---

## 3. Layout Shell & Navigation Components

### 3.1 Sticky Header & Navigation Bars
- **Sticky Header (`Header.tsx`, `TopNavBar.tsx`):**
  - Positioned at `top: 0`, `z-index: 20` with `var(--surface)` background and `var(--line)` bottom border.
  - Brand identity: 26px gradient dot + "Lazy Summer DAO" title (`font-weight: 600`).
  - Actions: Dark/Light Theme toggle (`DarkModeToggle.tsx`), "New proposal" shortcut button, and "Connect wallet" pill button (`ConnectButton.tsx`).
- **Sub-Nav Tabs:**
  - Active tabs: `Proposals`, `Treasury`, `Delegates`, `Create proposal`. (The `/cross-chain` standalone view is removed from tab nav).
  - Active tab indicated by `border-bottom: 2px solid var(--pink)` and `--fg` text.
- **Side Nav Rail (`SideNavBar.tsx`):**
  - Desktop sidebar updated to share `var(--surface)` background, `var(--line)` borders, and active pink accent states.
- **Mobile Bottom Nav (`BottomNavBar.tsx`):**
  - Fixed bottom bar using `var(--surface)` with `backdrop-filter: blur(16px)`, `border-top: 1px solid var(--line)`, and `pb-safe` spacing for mobile viewports.

---

## 4. Detailed Component Specifications by View

### 4.1 Proposals View (`src/app/proposals`, `src/app/proposals/v1`, `ProposalsList.tsx`, `ProposalList.tsx`, `ProposalFilter.tsx`)
- **Page Header:** `Proposals` (26px, weight 600) + subtitle *"Proposals are created and voted on Base. Satellite chains are execute-only."*
- **Status Filter Pills (`ProposalFilter.tsx`):**
  - Options: `All`, `Pending`, `Active`, `Executed`, `Executed on Hub`, `Queued`, `Defeated`, `Canceled`.
  - Styled as 30px pill buttons (`border-radius: 99px`) using semantic color backgrounds (`var(--okBg)`, `var(--warnBg)`, `var(--critBg)`, etc.).
- **Network Dropdown:**
  - Options: `All Networks`, `Ethereum`, `Base`, `Arbitrum`, `Sonic`, `Hyperliquid`.
  - Monospaced select box styled with `var(--field)` background and `var(--line2)` border.
- **Proposal Cards:**
  - Header: Monospaced SIP tag (`SIP4.3`), status badge, network badge (`Base`, `Ethereum`), and relative date timestamp.
  - Body: Left column has Title, summary prose, and "View details" button. Right column displays Quorum meter bar + For / Against / Abstain tally breakdown bars with monospaced percentages and total vote count.
  - Applies to both current proposals list and `/proposals/v1` list.

### 4.2 Proposal Detail View (`src/app/proposal/[id]`, `src/app/proposal/v1/[id]`, `ProposalExecutionDetails.tsx`, `ProposalVotingInfo.tsx`, `VotingModal.tsx`, `RecentVotes.tsx`, `CountdownTimer.tsx`)
- **Main Panel:** SIP Title, badge metadata, and full rendered markdown description.
- **Phase Timeline Indicator (`PhaseIndicator.tsx`):** Timeline steps (Pending → Active → Succeeded → Queued → Executed) styled with console badges.
- **Voting Panel (`ProposalVotingInfo.tsx`, `VotingModal.tsx`, `RecentVotes.tsx`):**
  - Monospaced stSUMR voting power display, vote progress meters, recent votes list, and voting modal using updated dialog styling.
- **Countdown Timer (`CountdownTimer.tsx`):** Monospaced countdown units (`d`, `h`, `m`, `s`) in `JetBrains Mono` with muted label text (`var(--fg3)`).
- **Proposed Actions Breakdown (`ProposalExecutionDetails.tsx`):**
  - Chain badge, target address (`0x...` in `JetBrains Mono`), decoded signature, selector display (showing published SIP selector string or `"Unknown, encode and verify"` without modifying selector resolution logic), parameters table, and calldata copy button.

### 4.3 Treasury View (`src/app/treasury`, `TreasuryView.tsx`, `TreasuryList.tsx`)
- **KPI Summary Grid:** Cards for **Total Treasury Value**, **Top Holding**, and **Wallets** set in 24px `JetBrains Mono` with 11px uppercase labels (`var(--fg3)`).
- **Top Holdings Panel:** Header *"Top holdings, aggregated"*. Rows displaying token logo mark, symbol, USD value, balance, and percentage share progress bar (`var(--grad)` fill).
- **Chain Filter Pills:** Option pills (`All chains`, `Mainnet`, `Base`, `Arbitrum`, `Sonic`, `Hyperliquid`) to filter wallet holdings by chain. (Note: token chain label uses `Mainnet` in line with Treasury data).
- **Wallet Sections:** Grouped wallet breakdowns (*Main Treasury*, *Arcadia PoL*, *Aerodrome Multisig*, *Guardians*) with token balances, chain tags, and USD values.

### 4.4 Delegates View (`src/app/delegates`, `DelegatesList.tsx`)
- **Header & Stats:** Search input (`⌕ Search delegates`) + stats cards (**Delegates** count e.g. 42, **Largest voting power**, **Most delegators**).
- **Delegate Cards Grid:** Avatar mark, Name, shortened address (`JetBrains Mono`), Rank badge (`#1`), 3-line bio, Voting Power, Delegators count, voting weight share bar, and "Delegate votes" button.
- **Pagination:** "Load more delegates" / "Show all 42 delegates" button at grid bottom.

### 4.5 Create Proposal & Simulation Center (`src/app/create-proposal`, `Form.tsx`, `SimulateProposalButton.tsx`, `SimulationCenter`)
- **Header & Toolbar:** Category tag `MULTI-CHAIN GOVERNANCE`, title, Import/Export JSON buttons, `SimulateProposalButton.tsx` (Run simulation), Skip Simulation toggle, and Submit button.
- **Action Builder (`Form.tsx`):** Chain selector, Target address, Method selector, dynamic parameter inputs with `--pink` type tags, pre-calculated/SIP-defined selector display, and validation blocker box.
- **Simulation Center:** On-chain eligibility checks, LayerZero satellite executor gas limit fields, and per-chain simulation status cards (*Idle*, *Not run yet*, *Done* with gas used in `JetBrains Mono` + execution trace trigger).

---

## 5. Build & Verification Commands

1. **Visual & Theme Verification:** Validate all views in both Dark and Light modes (`data-theme="light"` / `dark`) for proper color contrast and CSS variable resolution.
2. **Monospace & Alignment Checks:** Verify that all numbers, hashes, percentages, dates, and addresses render in `JetBrains Mono`.
3. **Responsive Testing:** Verify grid collapse on mobile viewports (`@media (max-width: 760px)`) and mobile bottom nav padding (`pb-safe`).
4. **Integration & Package Build:** Execute target build command:
   ```bash
   pnpm --filter @summerfi/summer-earn-gov-validator build
   ```
