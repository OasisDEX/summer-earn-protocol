# Summer Earn Interface — Design System

"Instrument panel at night": calm, precise, dark-only. This app is the permanent, self-contained
interface to the deployed protocol; the design favors legibility and restraint over decoration.

## Tokens (single source: `tailwind.config.js`)

| Role | Token | Value |
| --- | --- | --- |
| Page background | `surface` / `background` | `#0d0e10` |
| Panel surfaces | `surface-container(-low/-high/-highest)` | `#121316` → `#242629` |
| Primary text | `on-surface` | `#fdfbfe` |
| Secondary text | `on-surface-variant` | `#ababad` |
| Actions, links, focus | `primary` (hover `primary-dim`) | `#89acff` |
| APY, positive, deposits | `secondary` | `#68fadd` |
| Danger, withdraw, errors | `error` | `#ff716c` |
| Success notices | `success` | `#86e6b4` |
| Warnings | `warning` | `#ffcf87` |
| Informational | `info` | `#9ad8ff` |
| 7th categorical (charts) | `accent` | `#a7c1ff` |

Hairline borders: `border-white/10` (subtle: `/5`). Insets: `bg-white/5`, `bg-black/20`.
No raw Tailwind palette colors (`gray-*`, `blue-600`, …) and no ad-hoc hex classes.
Recharts series cycle: primary, secondary, info, success, warning, error, accent.

- **z-scale** (named, never numeric): `z-dropdown(30) < z-header(40) < z-modal(50) < z-toast(60)`.
- **Type:** Manrope (`font-headline`) for page/section titles; Inter body; both self-hosted via
  `next/font` (no external font requests — IPFS-friendly). `tabular-nums` on every numeric value;
  mono for addresses/hashes.
- **Signature:** the primary→secondary gradient hairline under the sticky header ("horizon line"),
  echoed on EmptyState/ErrorState tops. It is the app's only ambient glow.

## Primitives (`src/components/ui/`)

`Button` (never sets a default `type`), `Badge`, `Modal` (no `isOpen` prop — callers keep their
early return; `closeOnBackdrop` opt-in), `AddressDisplay` (always for addresses/hashes; `…`
ellipsis, hover `title` reveal), `PageHeader`/`SectionHeader`, `TableContainer`+`Table`/`Th`/`Td`
(`numeric` → right-aligned tabular figures; TableContainer is the only scroll wrapper),
`EmptyState`/`ErrorState`/`RetiredDataNotice` (subgraph sunset messaging), `formStyles`
(`inputBase`/`selectBase`/`labelBase`/`helpTextBase`/`checkboxBase` class constants).

Shared display formatting: `src/utils/address.ts` (`formatAddress`/`formatHash`) and
`src/utils/format.ts` (`formatNumber`/`formatPercent`/`formatCompact` + bigint-domain re-exports).
Display-only — never feed results into `parseUnits`, input values, or contract args.

## Rules of thumb

- Long dynamic strings (addresses, ids, amounts) always truncate or wrap deliberately — never
  overflow. Wide tables scroll inside `TableContainer`; the page body never scrolls horizontally.
- No fixed pixel widths around dynamic content (`max-w-*` + `w-full` instead).
- Empty/error/loading are designed states (Skeleton / EmptyState / ErrorState), not raw text.
- Pages do not paint their own canvas background — the root layout owns it.
