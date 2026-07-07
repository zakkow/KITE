# KITE — Clinical & HCI Grounding for Seed Constants
### What's cited, what's derived, and what's honest engineering judgment

This document exists so that if a judge, mentor, or curious teammate asks "where did these numbers come from," there's a real, checkable answer — not a vague "we researched it." Every source below is real and was retrieved and read before any number was set. Where the literature gives a precise, transferable number, it's used directly. Where it only supports a *qualitative* relationship (e.g. "tremor scatters more than general imprecision"), that's stated honestly rather than dressed up as a precise transcription.

---

## What changed as a result of this research

1. `KeyOffset.seeded()` variance values were re-derived (see table below).
2. `UserPreferences.keyHeightPoints` — **Standard** size raised from 42pt to **44pt**, to actually meet Apple's own documented minimum accessible touch target, rather than sitting 2pt under it.
3. The directional-shift vs. scatter-widening split (added in the previous revision) turns out to be independently supported by existing HCI research — this is described below, and is genuinely good news for the product story.

---

## Source 1 — Tremor frequency range

**Claim used:** Essential tremor oscillates at roughly 4–11 Hz; enhanced physiological tremor (what healthy people experience under stress/fatigue) covers roughly 7–12 Hz.

**Source:** Consensus Statement of the Movement Disorder Society on Tremor (Deuschl, Bain & Brin, 1998), and Gao, "Analysis of amplitude and frequency variations of essential and Parkinsonian tremors" (Medical and Biological Engineering and Computing, 2004) — both cited via: Sarcar et al., "Improving Input Accuracy on Smartphones for Persons Affected by Tremor using Motion Sensors" (2017), which states these ranges directly and cites both primary sources.

**How it's used:** This range is why the debounce window (default 80ms) is defensible as-is: the fastest documented tremor cycle (11 Hz) has a period of ~91ms. A debounce set close to but under that avoids conflating a genuine fast second keystroke with a same-cycle double-fire. No change made to the default — this is a citation supporting a value we already had, not a correction.

---

## Source 2 — Minimum accessible touch target size

**Claim used:** Apple's Human Interface Guidelines and Google's Material Design guidelines specify minimum tappable UI element sizes of 44×44pt and 48×48dp respectively, specifically so users with reduced motor precision can reliably hit targets.

**Source:** "MotorEase: Automated Detection of Motor Impairment Accessibility Issues in Mobile App UIs" (arXiv, 2024), which states this directly, citing Apple and Google's own published guidelines.

**How it's used — a real correction:** KITE's own "Standard" key height was set at 42pt, two points under Apple's documented minimum. **This is now corrected to 44pt.** This is the single clearest, most directly citable fix in this whole pass — an accessibility app whose default key size sits under Apple's own accessibility guideline is a real, avoidable flaw. Large (52pt) and Extra Large (64pt) were already comfortably above the minimum and are unchanged.

This number also sets the practical ceiling for scatter-widening radius: widening a key's hit-test past roughly half the minimum touch target starts causing keys to swallow their neighbors' rightful taps rather than correcting for imprecision. Seed values below stay well under that ceiling.

---

## Source 3 — Directional offset and scatter are two separate, independently-documented axes of touch error

**Claim used:** Touch input research distinguishes between a *systematic offset* (a consistent directional bias) and *touch precision/variability* (scatter around wherever the person is aiming) as two separate properties of a person's touch behavior — not one blended phenomenon.

**Source:** Azenkot & Zhai, "Touch Behavior with Different Postures on Soft Smartphone Keyboards" (2012), as summarized in Yi, Wang, Bi & Li, "Optimal virtual keyboard design..." (International Journal of Human-Computer Studies, 2017): *"despite a consistent touch offset, the touch precision of the participants was [still high]"* — i.e., the two properties vary independently in real user data.

**Why this matters for KITE:** This is direct, independent support for the core engineering decision in the correction engine — treating directional bias (`averageDeltaX/Y`) and scatter (`varianceX/Y`) as two separate tracked quantities, and choosing a correction mechanism based on which one dominates for a given key, rather than assuming one blended "offset" model fits everyone. This wasn't reverse-engineered to match the literature — it was independently arrived at to fix the tremor-averaging problem — but it's worth knowing the literature already treats these as separate axes, which makes the mechanism split easier to defend if asked.

---

## Source 4 — Personalized, per-individual touch models outperform generic ones for motor-impaired users

**Source:** Mott, Vatavu, Kane & Wobbrock, "Smart Touch: Improving Touch Accuracy for People with Motor Impairments with Template Matching" (CHI 2016) — found that predicting a person's intended touch point using an individually-learned model performed substantially better than generic/built-in touch resolution for users with motor impairments. Also: Findlater & Wobbrock's broader personalization work (2012) on adapting key-target distributions per individual.

**How it's used:** This directly supports KITE's core premise — that a per-user, per-key learned model (not a population dictionary) is the right approach — and is worth citing verbatim if a judge asks "why not just use a bigger keyboard for everyone."

---

## Source 5 — Cerebral palsy touchscreen accuracy is measurably and significantly impaired, on both hands

**Source:** Kaya Kara, Yardımcı, Livanelioglu & Soylu, "Examination of touch-coordinate errors of adolescents with unilateral spastic cerebral palsy at an aiming-tapping task" (Journal of Back and Musculoskeletal Rehabilitation, 2020). A case-control study (15 adolescents with unilateral spastic CP vs. 16 age-matched peers) measuring touch-coordinate error (TCE) and inter-touch interval (ITI) on a tablet aiming-tapping task. Found statistically significant differences in TCE between groups — notably on **both** the affected and unaffected hand.

**Honesty note:** This study establishes that touch-coordinate error is real, measurable, and significant in CP — which directly supports offering a Spasticity/CP profile at all — but the published abstract reports significance (p-values), not the raw mean error in mm/pt. So this source grounds the *qualitative* decision (CP produces real, elevated, directionally-relevant touch error worth correcting for) but not a specific numeric seed value. The spasticity seed below is therefore the least numerically-precise of the four and leans more on the general motor-impairment literature (Source 3, 4) plus proportional reasoning than on a transcribed number — flagged here rather than glossed over.

---

## Updated Seed Table

| Profile | Variance seed (pt, both axes) | Starting confidence | Grounding |
|---|---|---|---|
| Tremor | 6.5 | 0.30 | Upper end of the four — consistent with tremor being framed across the HCI literature (Sources 1, 3, 4) as the higher-scatter, lower-consistency category relative to general motor imprecision. Not a transcribed number — an order-of-magnitude estimate bounded by the touch-target ceiling in Source 2. |
| Spasticity / CP | 3.0 | 0.30 | Lower scatter than Tremor, consistent with literature framing directional/systematic offset (not raw scatter) as the more defining feature of this category (Source 3). Numerically the least precisely grounded — see honesty note under Source 5. |
| General Motor | 5.0 | 0.30 | Baseline — deliberately between Tremor and Spasticity, no directional assumption. |
| Not Sure Yet | 4.0 | 0.20 | Conservative default; lowest starting confidence since no profile-specific assumption is being made at all. |

All four values are well under the scatter-widening ceiling implied by Source 2 (roughly half of 44pt ≈ 22pt), so no seed risks swallowing a neighboring key's taps.

---

## What This Does and Doesn't Prove

This grounding makes the seed constants **defensible engineering estimates informed by real, cited research**, not arbitrary guesses. It does **not** make them clinically validated for any individual — that's exactly what your real tremor tester's session is for for. If their actual measured variance differs meaningfully from these seeds once you log it, adjust the seed for that profile type and note the change; that's the model doing exactly what it's supposed to do.