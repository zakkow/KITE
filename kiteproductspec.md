# KITE — Product Specification (v2)
### Keyboard Inclusion for Typing and Expression

---

## Purpose

Every keyboard ever built assumes your hands work the same way as everyone else's. iOS autocorrect is trained on population-level typo patterns. It has no idea that your left index finger consistently drifts northeast due to spasticity, or that your tremor oscillates around a key with no consistent direction at all. It corrects for the average human.

KITE builds a statistical model of your specific motor pattern and corrects for that — not for a dictionary, not for a population. For you.

KITE is not a medical device. It is an accessibility tool that makes the keyboard work the way your hands actually work, rather than forcing your hands to conform to a keyboard built for someone else.

**Primary users:** People with cerebral palsy, essential tremor, Parkinson's disease, multiple sclerosis, spinal cord injuries, or any condition affecting fine motor control.

**Secondary users:** Anyone with personal typing drift habits.

**Competition:** ECC Chicago "Everyone Can Code" iOS App Challenge — Accessibility theme.

---

## How KITE Works

KITE replaces the system keyboard with a custom keyboard extension. When a user taps a key, KITE captures the raw tap coordinate before any character is registered, determines which correction strategy applies to that key based on the *shape* of the user's data, resolves the corrected coordinate to the intended key, and inserts the correct character. The correction happens between the tap and the character appearing — invisible and instantaneous.

### Two correction mechanisms, chosen per key by the data itself

A single "average the offset and invert it" model works for a consistent directional pull (spasticity) but fails for oscillating tremor — an oscillation that swings roughly evenly around a key averages toward *zero*, leaving no stable vector to invert.

KITE tracks both the **mean drift** and the **variance** of every key's taps, and computes a **consistency ratio** (mean magnitude ÷ standard deviation) to decide which mechanism applies:

- **High consistency ratio → Directional Shift.** The bias is real and repeatable. KITE shifts the tap coordinate by the inverse of the learned vector before resolving the key. Most useful for spasticity-type drift, and for tremor patterns that settle into a consistent bias (e.g. after medication).
- **Low consistency ratio → Scatter Widening.** The bias is not stable — it's oscillation. KITE does not guess a direction. Instead it widens that key's effective hit-radius by its learned standard deviation and resolves the tap to the nearest key within that expanded radius. This is the primary mechanism for genuine tremor.

This split is per-key, not per-user — a person can have some keys that show consistent drift and others that show pure scatter, and KITE treats them independently. The self-reported profile (Tremor / Spasticity / CP / General) only sets the *starting point*; the actual mechanism used converges to what the data shows.

---

## Architecture

### Two-Target Xcode Project

**Container App (SwiftUI)** — onboarding, calibration, dashboard, heatmap, settings.
**Keyboard Extension (UIKit)** — a separate Xcode target, registered as a custom keyboard, runs across every app once enabled. Built in UIKit — keyboard extensions do not reliably support SwiftUI.

### Shared Data Layer
App Groups entitlement connects both targets through a shared container.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| Minimum iOS | iOS 16.0 |
| Container App UI | SwiftUI |
| Keyboard Extension UI | UIKit (UIInputViewController) |
| Shared Data | App Groups + UserDefaults(suiteName:) |
| Persistence | JSON-encoded motor profile in shared App Group container |
| Charts | Swift Charts |
| Motion Detection | CoreMotion (session fatigue awareness) |
| Correction Engine | Custom statistical offset + variance model — no external ML or API |

No external dependencies. No data leaves the device. No API keys required.

---

## User Profiles

Users select a base profile during onboarding. This sets **starting values only** — personal tap data overrides it key-by-key as the consistency ratio reveals what each key's pattern actually looks like.

| Profile | Starting Assumption | Converges To |
|---|---|---|
| Tremor | Moderate scatter, no assumed direction | Scatter widening on most keys; directional shift on any key that proves consistent |
| Spasticity / CP | Small scatter, direction learned fast | Directional shift once bias is confirmed (10+ samples) |
| General Motor | Moderate scatter, no directional assumption | Whatever the consistency ratio shows |
| Not Sure Yet | Conservative scatter, low starting confidence | Fully data-driven from first real session |

### Cold Start

Corrections are **not zero on tap one.** Every key starts with a population-seeded scatter radius appropriate to the selected profile type, so scatter-widening is active immediately. These seed values are informed by published tremor and motor-impairment touch research, not arbitrary guesses — full citations, including exactly which numbers are literature-derived versus engineering estimate, are documented in `06_KITE_ClinicalGrounding.md`. Directional shift is *not* applied until a key individually proves a consistent bias (consistency ratio above threshold, minimum 10 samples) — this is the more aggressive correction and needs real evidence first. Personal data blends in and dominates as sample count and confidence rise, reaching full personalization by roughly 200–300 taps.

### Seed Values Are Grounded in Published Research, Not Guessed

The starting scatter radius for each profile is derived from real motor-impairment touchscreen literature, converted to on-screen points:

| Profile | Seeded Scatter Radius | Basis |
|---|---|---|
| Tremor | 8pt | Fahn-Tolosa-Marin (FTM) tremor rating scale — clinical standard for essential tremor trials — bands mild tremor as visible movement under 1cm on a dot-approximation task. Converted conservatively (≈28pt ceiling at 1cm, seeded well below that) since a single tap's landing point samples a moment of the oscillation, not the full sustained-hold amplitude the FTM task measures. |
| Spasticity / CP | 3pt | Kept low deliberately — spasticity's defining trait is a *consistent* directional pull, not scatter, so the correction that matters is the learned directional-shift, not this seed. A touchscreen study of 38 users with motor disabilities (including CP) found this group averaged 3.9x more missed taps than non-disabled users at the same target sizes, but the deficit there is largely an accuracy/speed trade-off rather than pure randomness — consistent with a bias story, not a scatter story. |
| General Motor | 6pt | A study of 15 tetraplegic users recommended an 18mm minimum touchscreen target size for reliable use — larger than a typical ~10mm key. Translated conservatively into hit-test radius expansion (not visual button size, which is a different quantity) rather than applied literally. |
| Not Sure Yet | 5pt | Conservative midpoint blend of the above, since the profile is genuinely unknown at this point. |

**Honest caveat on precision:** these are order-of-magnitude anchors converted from clinical/HCI research, not numbers directly measured for "how far off does a tap land on an iOS keyboard." The point-conversion math (clinical cm/mm bands to iOS points) is our own reasoning applied to the literature, not itself a published constant. They are a much better starting point than an arbitrary guess, and they converge to the individual's real data within the first session regardless — the seed only matters for the first several dozen taps.

**Sources:**
- FTM tremor rating scale (dot-approximation amplitude bands) — CX-8998 Phase 2 trial protocol, ClinicalTrials.gov: `cdn.clinicaltrials.gov/large-docs/41/NCT03101241/Prot_000.pdf`
- Touch screen performance by individuals with and without motor control disabilities — `pubmed.ncbi.nlm.nih.gov/23021630` / ScienceDirect `S0003687012001226`
- Cluster Touch: Improving Touch Accuracy on Smartphones for People with Motor and Situational Impairments (15 tetraplegic participants) — ResearchGate `332741367`
- W3C WCAG 2.2 Understanding Target Size (Minimum), explicitly addressing hand tremors and spasticity — `w3.org/WAI/WCAG22/Understanding/target-size-minimum.html`

### Sub-profiles
**Finger vs Thumb:** distinguishes single-finger (scattered, unilateral) from thumb typing (symmetrical, bilateral).
**Velocity awareness:** faster typing raises the confidence bar to avoid overcorrection.

---

## Features

### Onboarding + Calibration
- Privacy statement, plain language: "Your motor profile never leaves your device. We collect nothing."
- Profile selector — four cards: Tremor, Spasticity / CP, General Motor, Not Sure Yet.
- Calibration sentences — five pangrams:
  1. "The quick brown fox jumps over the lazy dog"
  2. "Pack my box with five dozen liquor jugs"
  3. "How vexingly quick daft zebras jump"
  4. "Sphinx of black quartz, judge my vow"
  5. "Bright vixens jump dozy fowl quack"
- Skip option available — calibration is optional because population-seeded defaults already provide value.

### Keyboard Extension
**Core behavior:** correction fires between tap and character insertion; correction ripple (300ms amber pulse); small accuracy counter.

**Undo system:** undo strip after every correction; swipe left = undo (zero precision required). Three consecutive rejections resets that key's model back to its **population-seeded default**, not to zero — preserves the cold-start safety net.

**Key-repeat debounce:** default 80ms, adjustable.

**Additional guardrails:** key size scaling, keyboard height adjustment, long-press threshold, backspace ramp, caps lock debounce, auto-spacing, session fatigue detection. Confidence threshold gates directional shift only — scatter widening is not gated by confidence (see Cold Start above).

### Motor Profile Engine
**Per-key data stored:** mean offset (X/Y), variance (X/Y), consistency ratio (derived), confidence, acceptance rate, sample count.

**Learning:** weighted rolling average (recent taps 30%, history 70%) for both mean and variance, adapting to daily variation without discarding history.

### Dashboard, Heatmap, Settings
Numbers only, no marketing copy, heatmap as visual centerpiece (see UI/UX Spec). New: heatmap key detail popover indicates which correction mechanism is active for that key (directional vs scatter) — a real, explainable distinction rather than one blended algorithm.

### Privacy — Falsifiable, Not Just Promised
"No data leaves the device" is enforced as a **build-time fact**:
- `KITEKeyboard` target contains no `URLSession`, no `Network` import, no networking code.
- Checked mechanically before every demo build (see Coding Conduct — Privacy Verification).
- Talking point: *"Full access is requested for exactly one reason — reading the shared App Group container. There's no networking code compiled into that target at all. That's not a policy, it's a fact you could verify by reading the code."*

---

## Demo Strategy

### Presentation Structure (3:30)
| Time | Content |
|---|---|
| 0:00–0:25 | Teammate speaks — one true sentence about their loved one with a tremor. |
| 0:25–1:00 | The problem — type on standard iOS keyboard with demo profile. |
| 1:00–1:45 | The heatmap — before/after side by side. |
| 1:45–2:45 | Live demo — KITE keyboard in demo mode, ripple fires, dashboard shown. |
| 2:45–3:10 | "Every other keyboard was built for hands that don't shake. We built one for the ones that do." |
| 3:10–3:30 | Close — KITE, iOS 16+, motor profile stays on your device, gets smarter every session. |

### Demo Mode
Pre-seeded profile with exaggerated, **consistent directional drift** — chosen deliberately, since directional shift is the more visually dramatic correction live. Toggled via Settings.

### Validation Plan
Best case: test with a real person who has tremor before the final demo. Fallback: AI-assisted modeling of tremor/CP tap patterns to generate synthetic calibration data if a real tester isn't available in time. Real-person validation is the priority; synthetic modeling is the documented fallback.

---

## Future Enhancements (Post-Competition)
CoreML layer, multiple saved profiles, caregiver mode, cross-platform model export, expanded language support, iCloud profile sync, watchOS companion.

---

## What Makes KITE Win

Every other app in the competition demonstrates a feature. KITE demonstrates a relationship between the app and a specific human body — and it can explain, precisely, *why* it corrects the way it does for each key, because the correction strategy is chosen from the data, not assumed from a label.

The judges' conversation after presentations won't be "that was a useful app." It will be "wait — it actually learned their specific tremor pattern, and it knows the difference between a shake and a drift?"