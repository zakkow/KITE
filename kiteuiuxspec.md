# KITE — UI/UX Specification (v2)

*Unchanged from v1 except where marked **(new)**. Full v1 content (colors, typography, spacing, all screen specs, keyboard extension UI, navigation, accessibility requirements, app icon) still applies in full — this document only calls out what changed as a result of the correction-engine update.*

---

## Design Principles (unchanged)
Show, don't tell. For the user, not the demo. Nothing moves while you're reaching for it. Consistent, calm, confident.

## Visual Identity (unchanged)
`KITEAmber` #F5A623, `KITEBackground`, `KITESurface`, `KITEText`, `KITESecondary` #6C6C70, `KITEBlue` #4A90D9 (heatmap cool end), `KITERed` #D94A4A (heatmap hot end). SF Pro throughout, 8pt spacing base unit.

---

## Heatmap Screen — Detail Popover **(new addition)**

The correction engine now uses two distinct mechanisms per key (directional shift vs scatter widening), and this is worth surfacing — it's a real, explainable distinction, not marketing.

On key tap, the existing stats popover (sample count, acceptance rate, confidence score) gets one additional line:

- **Mechanism indicator** — small text label, numbers-only style consistent with the rest of the popover:
  - `"Directional"` — shown when that key's `isDirectionalDrift == true`
  - `"Widened"` — shown when the key is being corrected via scatter widening
  - `"Learning"` — shown when sample count is below `minSamplesForVarianceTrust` and neither mechanism has enough data yet

Style: same as existing popover text (numbers/short labels only, no explanatory sentences, `KITESecondary` color). This keeps the "show, don't tell" principle intact — a single word, not a paragraph.

No other heatmap changes. Color scale (cool blue = high confidence, amber = moderate, deep red = low), gradient interpolation, and the center-outward load animation all remain as specified in v1.

---

## Settings Screen (unchanged)
Profile section, Keyboard Feel section, Undo & Corrections section, Demo Mode toggle at bottom — all as v1. No new settings were needed for the correction engine update; the directional-vs-scatter choice is fully automatic and not user-configurable, by design — it should not require the user to understand the underlying mechanism to benefit from it.

## Dashboard Screen (unchanged)
Three metric chips, accuracy curve, session history list — all as v1.

## Onboarding / Calibration / Privacy Screens (unchanged)
All flows, copy, and layout as v1, including the five calibration pangrams and the non-skippable privacy screen.

## Keyboard Extension UI — one correction

**Standard key height is now 44pt, not 42pt** (v1 had this 2pt under Apple's own documented minimum accessible touch target — see 06_KITE_ClinicalGrounding.md, Source 2). Large (52pt) and Extra Large (64pt) are unchanged, both already comfortably above the minimum.

| Size Setting | Key Height | Font Size |
|---|---|---|
| Standard | **44pt** | 18pt |
| Large | 52pt | 20pt |
| Extra Large | 64pt | 22pt |

Everything else — QWERTY layout, correction ripple (300ms amber pulse), undo strip profile-aware placement table, in-keyboard accuracy counter — unchanged from v1.

## Accessibility Requirements (unchanged, still binding)
VoiceOver labels on every interactive element, including the new mechanism indicator (e.g. "Q key, high confidence, directional correction, 94% acceptance"). Dynamic Type, WCAG AA color contrast, and reduce-motion handling all still apply in full.

## App Icon (unchanged)
Finger pressing a key with an amber ripple. No text in icon.