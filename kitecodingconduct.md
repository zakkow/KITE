# KITE — Coding Conduct (v2)
### Rules every line of code in this project follows

---

## General Principles

**Correctness over cleverness.** If two implementations solve the same problem, choose the more readable one. Clever code that breaks during a live demo loses.

**No half-implementations.** Every feature is either fully built or not present. Placeholder UI with fake data is acceptable only in Demo Mode, explicitly labeled.

**Errors are handled, never swallowed.** Every `try` has a `catch`. Every optional unwrap has a fallback.

**No force unwraps in production code.** `!` is banned outside tests. Use `guard let`, `if let`, or a default.

**No magic numbers.** `0.6` is not a confidence threshold. `confidenceThreshold` is. This now also applies to the new variance/consistency constants — `KeyOffset.highConsistencyThreshold` and `KeyOffset.minSamplesForVarianceTrust` are named, not inlined.

---

## Swift Style

### Naming
- Types: `UpperCamelCase` — `MotorProfile`, `CorrectionEngine`, `KeyOffset`
- Functions/variables: `lowerCamelCase` — `resolveTap()`, `consistencyRatio`
- File names match the primary type they contain

### Functions
- One responsibility per function; break up anything over 40 lines
- Mutating functions named with verbs — `recordTap()`, `saveProfile()`
- Value-returning functions named with nouns/questions — `resolveTap()`, `offsetForKey()`

### Comments
- Comment the why, not the what
- `// Variance tracked against the pre-update mean — this is what lets us tell drift apart from oscillation` is good
- Mark edge cases: `// EDGE: three consecutive rejections resets to the seeded default, not zero`

### SwiftUI
- Each View is its own file, under 150 lines
- `@State` declared at the top, before `body`
- No business logic inside `body`

### UIKit (Keyboard Extension)
- `KeyboardViewController` is the only `UIInputViewController` subclass
- Programmatic layout only, no storyboards/XIBs
- All UI updates on main thread

---

## Data Safety

**App Group writes are atomic.** Encode the full object, verify it decodes, then write — never field by field.

```swift
func safeWrite(_ profile: MotorProfile) {
    guard let data = try? JSONEncoder().encode(profile),
          (try? JSONDecoder().decode(MotorProfile.self, from: data)) != nil else {
        return
    }
    SharedStore.defaults?.set(data, forKey: SharedKeys.motorProfile)
}
```

**Session raw-tap history is capped, not unbounded (new).**
`SessionData.rawTaps` is trimmed to `maxRawTapsRetained` (300) on every append. Aggregate stats (`totalKeystrokes`, `accuracyRate`, correction counts) are computed independently of `rawTaps.count` and are never affected by the trim. This exists because keyboard extensions are killed by iOS near ~120MB, and a long session storing every tap indefinitely is a real risk during exactly the moment you can least afford a crash — a live demo. Never remove this cap to "keep more debug data" without also adding a `#if DEBUG` gate around the larger retention.

**Session aggregates are append-only.** New sessions appended, never overwritten. Only user-initiated reset deletes history.

---

## Privacy

**No data leaves the device. Ever.** No analytics SDK, no crash reporting SDK, no API calls from the keyboard extension.

**Privacy is a verified build-time fact, not a stated intention (new).** Before any build shown to judges or users, run:

```bash
grep -rn "URLSession\|import Network" KITEKeyboard/ || echo "CLEAN: no networking code in keyboard extension"
```

If this command finds anything, the build does not ship until it's removed. This is a required step in the Day 6/7 integration checklist, not an optional sanity check — treat a failed grep the same as a failed unit test.

**Full access entitlement justification.** `RequestsOpenAccess = YES` in Info.plist exists for exactly one reason — reading the shared App Group container. Document this in a comment in Info.plist.

**No logging of keystrokes in production.**
```swift
#if DEBUG
print("Raw tap: \(rawPoint), corrected to: \(correctedKey)")
#endif
```

---

## Keyboard Extension Specifics

**Memory limit is strict (~120MB).** Avoid large assets. Motor profile JSON should stay a few KB. `SessionData.rawTaps` is capped per the Data Safety rule above — this is the primary new defense against hitting the ceiling during a real session.

**No network calls from the extension**, enforced by the grep check above — not just a style preference.

**Keyboard height must be set explicitly:**
```swift
let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
heightConstraint.priority = .required
heightConstraint.isActive = true
```

**Text insertion only via the documented API:**
```swift
textDocumentProxy.insertText(correctedCharacter)
```

---

## Error Handling Patterns

### App Group read failure
```swift
guard let data = SharedStore.defaults?.data(forKey: SharedKeys.motorProfile),
      let profile = try? JSONDecoder().decode(MotorProfile.self, from: data) else {
    return MotorProfile.default
}
```

### Calibration incomplete
Save whatever taps were collected as a partial profile. Never require completion to proceed.

### Correction engine unavailable
Degrade silently to passthrough mode. Never show an error inside the keyboard.

---

## Testing

**Every model function has a unit test**, including the new `consistencyRatio`, `isDirectionalDrift`, and `scatterRadius` computed properties on `KeyOffset` — these are the core of the tremor-vs-spasticity fix and deserve explicit known-input/known-output tests (e.g. a symmetric-scatter input should yield `isDirectionalDrift == false`; a strong one-directional input should yield `true`).

**Demo mode tested separately.** The pre-seeded demo profile must produce visible, consistent corrections on all five calibration sentences.

**Privacy check is part of the integration test, not separate from it** — see grep command above.

**Full integration test before every demo:**
1. Delete app, fresh install
2. Complete onboarding
3. Enable keyboard in Settings
4. Type in Messages — verify corrections fire, and that scatter-widening works even before calibration (cold start check)
5. Open KITE — verify dashboard reflects session
6. Enable demo mode — verify exaggerated directional corrections visible
7. Run the privacy grep check
8. Run all of the above without a crash

If step 6 is the only one that works reliably, that's your demo. Know your fallback.

---

## Git Conduct

- Commit after every completed day: `Day 3: Motor profile engine complete`
- Never commit directly to main while a demo build is pending
- Tag the demo build: `git tag v1.0-demo`
- Keep a `dev` branch for active work