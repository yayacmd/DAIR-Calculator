# DAIR Success Calculator — React component

A self-contained React port of the DAIR calculator for the Next.js static-export
+ Capacitor app. No iframe. Same validated model and exact TreeSHAP as the web
build — the scoring math is byte-identical (verified against the original
`randomForest` in R and against brute-force Shapley).

## Files

| File | Put it in |
|---|---|
| `DAIRCalculator.jsx` | your components dir, e.g. `components/DAIRCalculator.jsx` |
| `dairModel.js` | next to it, e.g. `components/dairModel.js` |
| `models.json`, `model_nculture.bin`, `model_culture.bin` | **`public/`** (served at the web root) |
| `Hip-and-Knee_ICM.pdf` *(optional)* | `public/` (only for the Info-panel link) |

The two `.bin` files are ~8 MB each; they're bundled into the app and loaded
from the local web root at runtime (no network). Only the no-culture model loads
on mount; the culture model loads lazily the first time the user selects
*Cultures obtained = Yes*.

## Use it

```jsx
'use client';
import DAIRCalculator from '@/components/DAIRCalculator';

export default function DairPage() {
  return <DAIRCalculator />;
}
```

### Props

| Prop | Default | Purpose |
|---|---|---|
| `basePath` | `''` | Prefix for asset fetches. Leave `''` when files are in `public/` and served at `/`. Set it if you deploy under a Next `basePath`/subpath. |
| `showArticles` | `true` | The Info panel's "recent PubMed articles" list (a live NCBI e-utils call). Set `false` for a fully offline build. |
| `showHeader` | `true` | The compact title row. Turn off if the app already shows a screen title. |
| `pdfHref` | `\`${basePath}/Hip-and-Knee_ICM.pdf\`` | Where the ICM PDF link points. Pass your own handler/URL to route it through the app's PDF viewer. |
| `themeKey` | `undefined` | Optional. Change it whenever you toggle the app theme in a way the built-in observers might miss (see Theming) to force the gauge/SHAP colors to re-read. |

## Theming (inherits the app's tokens)

The component consumes the host app's design tokens with the original ICM palette
as fallback, so it matches the new app automatically — including **dark mode** —
and still looks right standalone.

It reads these shadcn/Tailwind-style variables (fallback in parentheses):

| Component role | Token | Fallback |
|---|---|---|
| page background (recessed areas) | `--background` | `#FAFBFC` |
| cards / panels / inputs | `--card` | `#FFFFFF` |
| body text | `--foreground` | `#16202B` |
| secondary text | `--muted-foreground` | `#5B6B7C` |
| borders / hairlines | `--border` | `#E3E8EE` |
| brand / active control | `--primary` (+ `--primary-foreground`) | `#1B4FA0` / `#fff` |
| hover wash / chip / SHAP track | `--muted` | `#EEF3FB` |
| gauge success zone · SHAP "raises" | `--chart-2` | `#1A7F4B` |
| gauge mid zone · 0-day confirm hint | `--chart-4` | `#B7791F` |
| gauge danger zone · SHAP "lowers" · errors | `--destructive` | `#B3261E` |
| radius | `--radius` | `.625rem` |
| fonts | `--font-sans`, `--font-serif`, `--font-mono`/`--font-geist-mono` | IBM Plex / Source Serif |

No setup needed — if your `:root`/`.dark` defines these (it does), the component
follows. If you rename a token, either alias it on your root or tell me and I'll
remap.

### How it handles the gauge/SHAP (SVG)

CSS variables don't resolve inside SVG presentation attributes in iOS WKWebView,
so the DOM uses `var(--token, fallback)` directly while the **SVG colors are
resolved to concrete values at runtime** (via a hidden probe element) and
normalized through a canvas to a WKWebView-safe hex/rgb string. They re-read
automatically on theme change — the component observes `class`/`style`/`data-theme`
on `<html>` and `<body>`, and listens for `prefers-color-scheme`. That covers the
usual dark-mode toggles (`.dark` on `html`) and system dark mode.

**If you toggle the theme somewhere else** (e.g. a `.dark` class on a mid-tree
wrapper, not `html`/`body`), pass a changing `themeKey` prop at the same time so
the colors re-read:

```jsx
<DAIRCalculator themeKey={theme} />   // theme = 'light' | 'dark'
```

## Next.js static export

`next.config.mjs`:

```js
/** @type {import('next').NextConfig} */
export default {
  output: 'export',
  images: { unoptimized: true },
  // basePath: '/dair',   // only if you serve under a subpath — then pass basePath="/dair"
};
```

Build → `npx next build` produces `out/`. The `public/` assets (including the
`.bin` models) are copied into `out/` verbatim.

## Capacitor

```bash
npx next build            # -> out/
npx cap copy              # copies webDir (out/) into iOS/Android
```

- Set `webDir: 'out'` in `capacitor.config.*`.
- Local `fetch('/model_nculture.bin')` resolves against the app origin
  (`capacitor://localhost` on iOS, `https://localhost` on Android) and reads the
  bundled file — no special config needed.
- The PubMed list makes an outbound HTTPS call to `eutils.ncbi.nlm.nih.gov`. It
  degrades gracefully if blocked/offline, but for a strictly offline build pass
  `showArticles={false}` (avoids the request entirely). If you keep it, iOS ATS
  already allows HTTPS; no exception needed.

## Fonts

The component uses the ICM type stack (IBM Plex Sans / Source Serif 4 / IBM Plex
Mono) with system fallbacks. If the app doesn't already load them, add via
`next/font` in your root layout:

```js
import { IBM_Plex_Sans, IBM_Plex_Mono, Source_Serif_4 } from 'next/font/google';
// load and apply to <body> so the CSS var stacks resolve
```

Everything renders fine without them (falls back to the system UI font); the
fonts just match the ICM Assistant look exactly.

## Styling & scoping

Styles are injected as an inline `<style>` scoped under the component's root
class `.dair-calc`, so nothing leaks into the host app and there's no global-CSS
import (which Next disallows from components). All SVG/gauge colors are hex
literals (not CSS variables) so they render correctly in iOS WKWebView.

## Clinical behavior (unchanged from the web build)

- Blank start; the gauge + SHAP stay hidden until the required fields are set
  (6 numerics, 6 radio choices, and the cultures-obtained question), with a live
  "still needed" checklist.
- Binary comorbidity/complication/organism toggles default to absent.
- Non-blocking amber hint when a days field is left at 0.
- Once complete it updates live on every edit.

## Parity

`dairModel.js` is a straight port of the validated web engine. To re-confirm
end-to-end against the source model, run `validate_in_R.R` from the web build
against the original `DAIR.rds` / `DAIR2.rds` — the no-culture app-default is
0.9068 (91%) in every implementation.
