# DAO Console Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the new Summer DAO Console design system (`.resources/design/Summer DAO Console.dc.html` & `Summer Design System.dc.html`) across all views in `@summerfi/summer-earn-gov-validator`.

**Architecture:** Integrate CSS variables into `globals.scss` with dark mode default and `data-theme="light"` overrides. Map CSS tokens into `tailwind.config.js` and update header, side/bottom navigation, proposals, proposal details, treasury, delegates, create proposal, and simulation components.

**Tech Stack:** Next.js (App Router), Tailwind CSS, SCSS, Inter & JetBrains Mono Google Fonts, React, TypeScript, Viem/Wagmi.

---

### Task 1: CSS Variables & Design System Token Integration

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/styles/globals.scss`
- Modify: `packages/summer-earn-gov-validator/tailwind.config.js`

- [ ] **Step 1: Update globals.scss with CSS color variables and JetBrains Mono font**

Edit `packages/summer-earn-gov-validator/src/styles/globals.scss` to import `JetBrains Mono` alongside `Inter`, define `:root` dark variables, and `[data-theme="light"]` overrides:

```scss
@tailwind base;
@tailwind components;
@tailwind utilities;

@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap');

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

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: Inter, system-ui, sans-serif;
  font-size: 14px;
  line-height: 1.5;
  letter-spacing: -0.006em;
  -webkit-font-smoothing: antialiased;
}

.font-mono {
  font-family: 'JetBrains Mono', monospace !important;
}
```

- [ ] **Step 2: Update tailwind.config.js to bind CSS variables**

Update `packages/summer-earn-gov-validator/tailwind.config.js` to add font families and color mapping:

```js
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        bg: 'var(--bg)',
        surface: 'var(--surface)',
        surface2: 'var(--surface2)',
        surface3: 'var(--surface3)',
        field: 'var(--field)',
        line: 'var(--line)',
        line2: 'var(--line2)',
        fg: 'var(--fg)',
        fg2: 'var(--fg2)',
        fg3: 'var(--fg3)',
        pink: 'var(--pink)',
        pinkHi: 'var(--pinkHi)',
        violet: 'var(--violet)',
        ok: 'var(--ok)',
        warn: 'var(--warn)',
        crit: 'var(--crit)',
        info: 'var(--info)',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
    },
  },
  plugins: [require('@tailwindcss/typography')],
}
```

- [ ] **Step 3: Test CSS variables compilation**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/styles/globals.scss packages/summer-earn-gov-validator/tailwind.config.js
git commit -m "style(gov-validator): add DAO console CSS variables and font tokens"
```

---

### Task 2: Sticky Header, Navigation Bars & Theme Toggle

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/Header.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/TopNavBar.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/SideNavBar.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/BottomNavBar.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/DarkModeToggle.tsx`

- [ ] **Step 1: Redesign Header.tsx & TopNavBar.tsx**

Update `Header.tsx` / `TopNavBar.tsx` with sticky container (`position: sticky; top: 0; z-index: 20`), brand gradient dot logo, "Lazy Summer DAO" title, theme toggle button, "New proposal" link button, "Connect wallet" button, and horizontal sub-nav tabs (`Proposals`, `Treasury`, `Delegates`, `Create proposal`).

- [ ] **Step 2: Update SideNavBar.tsx & BottomNavBar.tsx**

Restyle `SideNavBar.tsx` and `BottomNavBar.tsx` to use `var(--surface)`, `var(--line)` borders, active pink tab indicators, and `pb-safe` padding for mobile screens.

- [ ] **Step 3: Update DarkModeToggle.tsx**

Ensure `DarkModeToggle.tsx` toggles `data-theme="light"` / `data-theme="dark"` attribute on `document.documentElement` or container element.

- [ ] **Step 4: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/Header.tsx packages/summer-earn-gov-validator/src/components/TopNavBar.tsx packages/summer-earn-gov-validator/src/components/SideNavBar.tsx packages/summer-earn-gov-validator/src/components/BottomNavBar.tsx packages/summer-earn-gov-validator/src/components/DarkModeToggle.tsx
git commit -m "feat(gov-validator): update header, top/side/bottom navigation, and theme toggle"
```

---

### Task 3: Proposals List & Filter Components

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalFilter.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalsList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/proposals/page.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/proposals/v1/page.tsx`

- [ ] **Step 1: Update ProposalFilter.tsx**

Update status filter options to `All`, `Pending`, `Active`, `Executed`, `Executed on Hub`, `Queued`, `Defeated`, `Canceled` with 30px pill styling (`border-radius: 99px`), and network dropdown options (`All Networks`, `Ethereum`, `Base`, `Arbitrum`, `Sonic`, `Hyperliquid`).

- [ ] **Step 2: Restyle ProposalsList.tsx & ProposalList.tsx cards**

Format proposal cards with monospaced SIP tags (`SIP4.3`), status badges (`var(--okBg)` / `var(--critBg)`), network badges, Quorum progress bars (`height: 6px`), and For / Against / Abstain tally breakdown bars (`height: 4px`, monospaced percentages in `JetBrains Mono`).

- [ ] **Step 3: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/ProposalFilter.tsx packages/summer-earn-gov-validator/src/components/ProposalsList.tsx packages/summer-earn-gov-validator/src/components/ProposalList.tsx packages/summer-earn-gov-validator/src/app/proposals/
git commit -m "feat(gov-validator): apply DAO console styling to proposals list and filters"
```

---

### Task 4: Proposal Detail & Execution Components

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalExecutionDetails.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalVotingInfo.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/PhaseIndicator.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/CountdownTimer.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/VotingModal.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/RecentVotes.tsx`

- [ ] **Step 1: Restyle ProposalExecutionDetails.tsx**

Format proposed action targets with network tags, monospaced addresses, decoded function signatures, pre-calculated selector display ("Unknown, encode and verify" fallback), parameter tables, and calldata copy button.

- [ ] **Step 2: Restyle VotingInfo, PhaseIndicator, CountdownTimer & Modal**

Format stSUMR voting power displays, voting progress meters, phase progress indicators, and monospaced unit timer (`CountdownTimer.tsx`) in `JetBrains Mono`.

- [ ] **Step 3: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/ProposalExecutionDetails.tsx packages/summer-earn-gov-validator/src/components/ProposalVotingInfo.tsx packages/summer-earn-gov-validator/src/components/PhaseIndicator.tsx packages/summer-earn-gov-validator/src/components/CountdownTimer.tsx packages/summer-earn-gov-validator/src/components/VotingModal.tsx packages/summer-earn-gov-validator/src/components/RecentVotes.tsx
git commit -m "feat(gov-validator): apply console styling to proposal details and execution views"
```

---

### Task 5: Treasury View & Wallet Breakdowns

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/TreasuryView.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/TreasuryList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/treasury/page.tsx`

- [ ] **Step 1: Redesign TreasuryView.tsx summary metrics & holdings table**

Format KPI grid for **Total Treasury Value**, **Top Holding**, and **Wallets** in 24px `JetBrains Mono`. Restyle "Top holdings, aggregated" panel with token logo marks, balances, USD values, and share progress bars (`var(--grad)`).

- [ ] **Step 2: Add chain filter pills & wallet breakdown cards**

Add chain filter pills (`All chains`, `Mainnet`, `Base`, `Arbitrum`, `Sonic`, `Hyperliquid`). Restyle wallet breakdown sections (*Main Treasury*, *Arcadia PoL*, *Aerodrome Multisig*, *Guardians*).

- [ ] **Step 3: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/TreasuryView.tsx packages/summer-earn-gov-validator/src/components/TreasuryList.tsx packages/summer-earn-gov-validator/src/app/treasury/page.tsx
git commit -m "feat(gov-validator): redesign Treasury view with aggregated holdings and wallet cards"
```

---

### Task 6: Delegates List & Search View

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/DelegatesList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/delegates/page.tsx`

- [ ] **Step 1: Redesign Delegates header, search, and stats**

Add monospaced search bar (`⌕ Search delegates`), stats cards (**Delegates** count, **Largest voting power**, **Most delegators**) in `JetBrains Mono`.

- [ ] **Step 2: Redesign delegate card grid & pagination button**

Restyle delegate cards with avatar marks, rank badges (`#1`), monospaced addresses, 3-line bio clamping, voting power share bars, and "Delegate votes" pill buttons. Add bottom pagination button ("Load more delegates" / "Show all 42 delegates").

- [ ] **Step 3: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/DelegatesList.tsx packages/summer-earn-gov-validator/src/app/delegates/page.tsx
git commit -m "feat(gov-validator): redesign Delegates view with search, stats, and cards grid"
```

---

### Task 7: Create Proposal & Simulation Components

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/Form.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/SimulationCenter/` (and `SimulateProposalButton.tsx`)
- Modify: `packages/summer-earn-gov-validator/src/app/create-proposal/page.tsx`

- [ ] **Step 1: Redesign Form.tsx proposal action builder**

Style title input, tabbed Markdown/Preview description editor, multi-chain action card items (Chain dropdown, Target input in `JetBrains Mono`, Method signature selector, parameter inputs with `--pink` type badges), selector hash display, and validation blocker alert box.

- [ ] **Step 2: Redesign Simulation Center & LayerZero Satellite Gas Limits**

Restyle proposer eligibility card, LayerZero satellite chain executor gas limit fields, and simulation status cards (*Idle*, *Not run yet*, *Done* with gas numbers in `JetBrains Mono` and execution trace button).

- [ ] **Step 3: Verify full application build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/Form.tsx packages/summer-earn-gov-validator/src/components/SimulationCenter/ packages/summer-earn-gov-validator/src/app/create-proposal/
git commit -m "feat(gov-validator): redesign Create Proposal form and Simulation Center"
```
