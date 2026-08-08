# DAO Console Redesign Implementation Plan (Revision 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the new Summer DAO Console design system (`.resources/design/Summer DAO Console.dc.html` & `Summer Design System.dc.html`) across all views and components in `@summerfi/summer-earn-gov-validator`.

**Architecture:** Define `:root` dark mode defaults and `[data-theme="light"]` overrides in `globals.scss`. Map CSS variables into `tailwind.config.js` while aliasing all legacy semantic color classes (`surface-container`, `on-surface-variant`, `primary`, `error`, etc.) to prevent unstyling existing components. Load Google Fonts (`Inter`, `JetBrains Mono`) and SSR theme initialization in `layout.tsx`. Update navigation, proposal lists, proposal details (including v1 routes), treasury, delegates, create proposal page (`src/app/create-proposal/page.tsx`), AppKit providers, and loading/error states.

**Tech Stack:** Next.js (App Router), Tailwind CSS, SCSS, Inter & JetBrains Mono Google Fonts, React, TypeScript, Viem/Wagmi, Reown AppKit.

---

### Task 1: CSS Variables, Font Loading & Non-Breaking Tailwind Token Aliases

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/styles/globals.scss`
- Modify: `packages/summer-earn-gov-validator/tailwind.config.js`
- Modify: `packages/summer-earn-gov-validator/src/app/layout.tsx`

- [ ] **Step 1: Update globals.scss with CSS color variables (no render-blocking @import)**

Edit `packages/summer-earn-gov-validator/src/styles/globals.scss` to define `:root` dark variables, `[data-theme="light"]` overrides, and JetBrains Mono utility class. (Font imports are handled via `<link>` in `layout.tsx` to prevent PostCSS `@import` ordering warnings):

```scss
@tailwind base;
@tailwind components;
@tailwind utilities;

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

- [ ] **Step 2: Update tailwind.config.js preserving legacy color aliases**

Update `packages/summer-earn-gov-validator/tailwind.config.js` to add new design tokens while mapping legacy semantic names (`surface-container`, `on-surface-variant`, `background`, `surface`, `primary`, `error`, `success`, `warning`, `outline-variant`) to CSS variables so existing components remain fully styled:

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
    './src/config/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        // Design System Variables
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

        // Legacy Semantic Aliases (Non-Breaking)
        'surface-container': 'var(--surface2)',
        'surface-container-high': 'var(--surface3)',
        'surface-container-lowest': 'var(--bg)',
        'surface-dim': 'var(--bg)',
        'surface-bright': 'var(--surface2)',
        'surface-variant': 'var(--surface2)',
        background: 'var(--bg)',
        primary: 'var(--pink)',
        'primary-fixed': 'var(--pink)',
        'primary-fixed-dim': 'var(--pinkHi)',
        secondary: 'var(--violet)',
        'on-surface': 'var(--fg)',
        'on-surface-variant': 'var(--fg2)',
        'on-background': 'var(--fg)',
        outline: 'var(--line2)',
        'outline-variant': 'var(--line)',
        error: 'var(--crit)',
        success: 'var(--ok)',
        warning: 'var(--warn)',
        'error-container': 'var(--critBg)',
        'on-error-container': 'var(--crit)',

        // Chain Colors
        'chain-base': '#0052FF',
        'chain-arbitrum': 'var(--violet)',
        'chain-mainnet': 'var(--pink)',
        'chain-sonic': '#00e5ff',
        'chain-hyperliquid': 'var(--info)',
      },
      fontFamily: {
        headline: ['Inter', 'system-ui', 'sans-serif'],
        body: ['Inter', 'system-ui', 'sans-serif'],
        label: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      backgroundImage: {
        'brand-gradient': 'var(--grad)',
      },
    },
  },
  plugins: [require('@tailwindcss/typography')],
}
```

- [ ] **Step 3: Update layout.tsx with font links & anti-flash script**

Update `packages/summer-earn-gov-validator/src/app/layout.tsx` to include `Inter` & `JetBrains Mono` `<link>` elements, anti-flash inline theme script (`<script dangerouslySetInnerHTML={{ __html: "(function(){try{var t=localStorage.getItem('theme')||'dark';document.documentElement.setAttribute('data-theme',t);if(t==='dark')document.documentElement.classList.add('dark');else document.documentElement.classList.remove('dark');}catch(e){}})()" }} />`), and `data-theme="dark"` default:

```tsx
import type { Metadata } from 'next'
import { Providers } from '../components/Providers'
import '@/styles/globals.scss'

export const metadata: Metadata = {
  title: 'Summer.fi DAO | Governance Validator',
  description: 'Participate in the Lazy Summer DAO. Validate, review, and vote on governance proposals shaping the future of the Summer Earn Protocol.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" className="dark">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap"
          rel="stylesheet"
        />
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('theme')||'dark';document.documentElement.setAttribute('data-theme',t);if(t==='dark')document.documentElement.classList.add('dark');else document.documentElement.classList.remove('dark');}catch(e){}})()`,
          }}
        />
      </head>
      <body className="bg-bg text-fg font-body min-h-screen">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

- [ ] **Step 4: Run build check**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit**

```bash
git add packages/summer-earn-gov-validator/src/styles/globals.scss packages/summer-earn-gov-validator/tailwind.config.js packages/summer-earn-gov-validator/src/app/layout.tsx
git commit -m "style(gov-validator): add CSS variables, non-breaking tailwind aliases, and layout font/theme hydration"
```

---

### Task 2: Header, Navigation Shell, Theme Toggle & AppKit Providers

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/Header.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/TopNavBar.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/SideNavBar.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/BottomNavBar.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/DarkModeToggle.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/Providers.tsx`

- [ ] **Step 1: Redesign Header.tsx & TopNavBar.tsx**

Update `Header.tsx` / `TopNavBar.tsx` with sticky container (`position: sticky; top: 0; z-index: 20`), brand gradient dot logo, "Lazy Summer DAO" title, theme toggle button, "New proposal" link button, "Connect wallet" button, and horizontal sub-nav tabs (`Proposals`, `Treasury`, `Delegates`, `Create proposal`).

- [ ] **Step 2: Update SideNavBar.tsx & BottomNavBar.tsx**

Restyle `SideNavBar.tsx` and `BottomNavBar.tsx` to use `var(--surface)`, `var(--line)` borders, active pink tab indicators, and `pb-safe` padding for mobile screens.

- [ ] **Step 3: Update DarkModeToggle.tsx & Providers.tsx**

Ensure `DarkModeToggle.tsx` toggles both `data-theme` attribute and `dark` class on `document.documentElement` while persisting choice to `localStorage`. Configure Reown AppKit theme variables in `Providers.tsx` to align modal colors with `var(--surface)` and `var(--pink)`.

- [ ] **Step 4: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/Header.tsx packages/summer-earn-gov-validator/src/components/TopNavBar.tsx packages/summer-earn-gov-validator/src/components/SideNavBar.tsx packages/summer-earn-gov-validator/src/components/BottomNavBar.tsx packages/summer-earn-gov-validator/src/components/DarkModeToggle.tsx packages/summer-earn-gov-validator/src/components/Providers.tsx
git commit -m "feat(gov-validator): update navigation shell, theme toggle, and wallet provider theme"
```

---

### Task 3: Proposals List, Filter & Skeleton Components

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalFilter.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalsList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalsListSkeleton.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/proposals/page.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/proposals/v1/page.tsx`

- [ ] **Step 1: Update ProposalFilter.tsx**

Update status filter options to `All`, `Pending`, `Active`, `Executed`, `Executed on Hub`, `Queued`, `Defeated`, `Canceled` with 30px pill styling (`border-radius: 99px`), and network dropdown options (`All Networks`, `Ethereum`, `Base`, `Arbitrum`, `Sonic`, `Hyperliquid`).

- [ ] **Step 2: Restyle ProposalsList.tsx, ProposalList.tsx & Skeleton**

Format proposal cards with monospaced SIP tags (`SIP4.3`), status badges (`var(--okBg)` / `var(--critBg)`), network badges, Quorum progress bars (`height: 6px`), and For / Against / Abstain tally breakdown bars (`height: 4px`, monospaced percentages in `JetBrains Mono`). Update `ProposalsListSkeleton.tsx` to reflect the new 12px rounded console card layout.

- [ ] **Step 3: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/ProposalFilter.tsx packages/summer-earn-gov-validator/src/components/ProposalsList.tsx packages/summer-earn-gov-validator/src/components/ProposalList.tsx packages/summer-earn-gov-validator/src/components/ProposalsListSkeleton.tsx packages/summer-earn-gov-validator/src/app/proposals/
git commit -m "feat(gov-validator): apply console design to proposals list, filters, and skeleton"
```

---

### Task 4: Proposal Detail, Execution & Voting Modals

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalExecutionDetails.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalVotingInfo.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/PhaseIndicator.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/CountdownTimer.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/VotingModal.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/ProposalModal.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/RecentVotes.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/proposal/[id]/page.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/proposal/v1/[id]/page.tsx`

- [ ] **Step 1: Restyle ProposalExecutionDetails.tsx & Pages**

Format proposed action targets in `ProposalExecutionDetails.tsx` and detail pages (`/proposal/[id]` and `/proposal/v1/[id]`) with network tags, monospaced addresses, decoded function signatures, pre-calculated selector display ("Unknown, encode and verify" fallback), parameter tables, and calldata copy button.

- [ ] **Step 2: Restyle VotingInfo, PhaseIndicator, CountdownTimer & Modals**

Format stSUMR voting power displays, voting progress meters, phase progress indicators, monospaced unit timer (`CountdownTimer.tsx`), and modal dialogs (`VotingModal.tsx`, `ProposalModal.tsx`) using console card panels (`var(--surface)` background, `var(--line)` borders).

- [ ] **Step 3: Verify build**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/components/ProposalExecutionDetails.tsx packages/summer-earn-gov-validator/src/components/ProposalVotingInfo.tsx packages/summer-earn-gov-validator/src/components/PhaseIndicator.tsx packages/summer-earn-gov-validator/src/components/CountdownTimer.tsx packages/summer-earn-gov-validator/src/components/VotingModal.tsx packages/summer-earn-gov-validator/src/components/ProposalModal.tsx packages/summer-earn-gov-validator/src/components/RecentVotes.tsx packages/summer-earn-gov-validator/src/app/proposal/
git commit -m "feat(gov-validator): apply console styling to proposal detail pages, modals, and execution views"
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
git commit -m "feat(gov-validator): redesign Treasury view with aggregated holdings, chain pills, and wallet cards"
```

---

### Task 6: Delegates List & Search View

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/components/DelegatesList.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/delegates/page.tsx`

- [ ] **Step 1: Redesign Delegates header, search, and stats**

Add monospaced search bar (`⌕ Search delegates`), stats cards (**Delegates** count e.g. 42, **Largest voting power**, **Most delegators**) in `JetBrains Mono`.

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

### Task 7: Create Proposal Page, Simulation & App Feedback States

**Files:**
- Modify: `packages/summer-earn-gov-validator/src/app/create-proposal/page.tsx`
- Modify: `packages/summer-earn-gov-validator/src/components/SimulationCenter/SimulationCenter.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/loading.tsx`
- Modify: `packages/summer-earn-gov-validator/src/app/error.tsx`

- [ ] **Step 1: Redesign src/app/create-proposal/page.tsx action builder & gas panel**

Restyle title input, tabbed Markdown/Preview description editor, multi-chain action card items (Chain dropdown, Target input in `JetBrains Mono`, Method signature selector, parameter inputs with `--pink` type badges), selector hash display, validation blocker alert box, and LayerZero satellite gas limits panel in `src/app/create-proposal/page.tsx`.

- [ ] **Step 2: Redesign Simulation Center & App Loading/Error states**

Restyle `SimulationCenter.tsx` status cards (*Idle*, *Not run yet*, *Done* with gas numbers in `JetBrains Mono` and execution trace button). Restyle `loading.tsx` spinner and `error.tsx` error boundaries with `var(--surface)` panels and `var(--pink)` brand accenting.

- [ ] **Step 3: Run full package build & lint verification**

Run: `pnpm --filter @summerfi/summer-earn-gov-validator build && pnpm --filter @summerfi/summer-earn-gov-validator lint`  
Expected: PASS (Zero build or lint errors)

- [ ] **Step 4: Commit**

```bash
git add packages/summer-earn-gov-validator/src/app/create-proposal/page.tsx packages/summer-earn-gov-validator/src/components/SimulationCenter/ packages/summer-earn-gov-validator/src/app/loading.tsx packages/summer-earn-gov-validator/src/app/error.tsx
git commit -m "feat(gov-validator): redesign Create Proposal page, Simulation Center, loading and error views"
```
