# KITE — Build Specification (v2)

---

## Project Setup

- **Xcode:** 26.4 (or current stable) — mechanics below (New Target → Custom Keyboard Extension, Signing & Capabilities → App Groups) have been stable across Xcode versions; only exact menu wording may differ from what's described.
- **Deployment target:** iOS 16.0
- **Swift version:** 5.9+
- **Bundle ID (container app):** com.kite.app
- **Bundle ID (keyboard extension):** com.kite.app.keyboard
- **App Group identifier:** group.com.kite.shared

### Targets
| Target | Type | Bundle ID |
|---|---|---|
| KITE | iOS App | com.kite.app |
| KITEKeyboard | Custom Keyboard Extension | com.kite.app.keyboard |

Both targets need the App Groups entitlement, identifier `group.com.kite.shared`.

---

## File Structure

```
KITE/
├── KITE/ (container app)
│   ├── App/ (KITEApp.swift, ContentView.swift)
│   ├── Onboarding/ (OnboardingView, PrivacyView, ProfileSelectorView, CalibrationView)
│   ├── Dashboard/ (DashboardView, AccuracyCurveView)
│   ├── Heatmap/ (HeatmapView)
│   ├── Settings/ (SettingsView)
│   └── Assets.xcassets
│
├── KITEKeyboard/ (keyboard extension)
│   ├── KeyboardViewController.swift
│   ├── KeyboardView.swift
│   ├── KeyView.swift
│   ├── CorrectionEngine.swift
│   ├── UndoStrip.swift
│   └── Info.plist
│
└── Shared/ (added to BOTH targets)
    ├── SharedStore.swift
    ├── MotorProfile.swift
    ├── KeyOffset.swift
    ├── SessionData.swift
    ├── UserPreferences.swift
    └── PreferencesStore.swift
```

---

## Shared Data Layer

All shared data lives in `UserDefaults(suiteName: "group.com.kite.shared")`. See `SharedStore.swift` in the Agent Prompts document for the complete, ready-to-paste implementation.

---

## Data Models — What Changed From v1

### KeyOffset now tracks variance, not just mean drift

**Why:** the original model only stored an average offset vector. For a genuinely oscillating tremor, that average trends toward zero — there's no stable direction to invert. Adding variance lets the engine compute a **consistency ratio** that tells directional bias (spasticity-like) apart from pure scatter (tremor-like), per key.

New fields: `varianceX`, `varianceY`, plus derived `consistencyRatio`, `isDirectionalDrift`, and `scatterRadius`. Full implementation in Agent Prompts.

### KeyOffset now has a `seeded(for:profileType:)` cold-start constructor

**Why:** the v1 model started every key at zero offset and zero confidence, meaning corrections did nothing until ~50+ samples accumulated. `seeded()` gives each key a population-level starting scatter radius based on the selected profile type, so scatter-widening is useful from tap one. Confidence still starts low and climbs with real data — the seed is a safety net, not a final answer.

### CorrectionEngine now branches per key: directional shift vs scatter widening

**Why:** this is the actual fix for the tremor-averaging problem. Directional shift (coordinate offset by the inverse mean) only fires when `isDirectionalDrift` is true — meaning the consistency ratio proves the bias is real, not just noise. Otherwise, the engine falls back to scatter widening: expanding each key's hit-test frame by its learned (or seeded) standard deviation and resolving to the nearest key within that radius. This mechanism is **not gated by the confidence threshold** — it uses seeded variance immediately, unlike directional shift which needs earned evidence.

### SessionData now caps raw tap history

**Why:** keyboard extensions are killed by iOS around ~120MB. Storing every raw tap indefinitely risks hitting that ceiling during a long demo or session — the worst possible moment for a crash. `SessionData.maxRawTapsRetained = 300` trims oldest entries while aggregate stats (accuracy rate, correction counts) are computed independently and are unaffected by the trim.

Full corrected implementations of all four files are in the Agent Prompts document — paste those directly, they supersede anything summarized here.

---

## UserPreferences

Unchanged from v1. Full struct (KeySize, KeyboardHeight, BackspaceSpeed, Sensitivity, UndoSize enums, plus derived `confidenceThreshold`, `keyHeightPoints`, `keyboardHeightPoints`, `backspaceInterval`) is in Agent Prompts, Day 3.

**Read/write pattern** (container writes, keyboard reads on every `viewDidLoad` — preferences can change between sessions):

```swift
func savePreferences(_ prefs: UserPreferences) {
    guard let data = try? JSONEncoder().encode(prefs),
          (try? JSONDecoder().decode(UserPreferences.self, from: data)) != nil else {
        return
    }
    SharedStore.defaults?.set(data, forKey: SharedStore.Keys.userPreferences)
}

func loadPreferences() -> UserPreferences {
    guard let data = SharedStore.defaults?.data(forKey: SharedStore.Keys.userPreferences),
          let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
        return UserPreferences.default
    }
    return prefs
}
```

---

## Keyboard Extension

### KeyboardViewController.swift
Subclass of `UIInputViewController`. Loads motor profile + preferences on `viewDidLoad` (every time it reappears, not just first launch). Handles tap events → `CorrectionEngine.resolveTap()` → insert character → `recordTap()` → periodic `saveProfile()`.

### Correction Ripple
```swift
func animateRipple(on keyView: KeyView) {
    UIView.animate(withDuration: 0.1, animations: {
        keyView.backgroundColor = UIColor(named: "KITEAmber")?.withAlphaComponent(0.6)
    }) { _ in
        UIView.animate(withDuration: 0.2) {
            keyView.backgroundColor = .systemGray5
        }
    }
}
```

---

## Demo Mode

Pre-seeded `MotorProfile.demo` uses **consistent directional drift** (low variance relative to a large mean offset), deliberately chosen so the directional-shift mechanism fires — it's the more visually dramatic correction for a live audience. See Agent Prompts for the exact values.

---

## Privacy Verification (New)

Run before every build shown to judges:

```bash
grep -rn "URLSession\|import Network" KITEKeyboard/ || echo "CLEAN: no networking code in keyboard extension"
```

If this returns any match, stop and remove it before demoing. This check should be part of the Day 6/7 integration checklist, not a one-time thing.

---

## English Only (MVP)
`UITextInputMode` is not overridden. Keyboard operates in English only for MVP.