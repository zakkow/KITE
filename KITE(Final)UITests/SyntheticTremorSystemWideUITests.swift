import XCTest

final class SyntheticTremorSystemWideUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Checks both .buttons and .keys — some iOS/Xcode combinations
    /// classify keyboard extension buttons one way, some the other. This
    /// makes lookups robust to that rather than assuming either.
    private func element(named name: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[name]
        if button.exists { return button }
        return app.keys[name]
    }

    /// Cycles "Next keyboard" up to 3 times, checking for a KITE-specific
    /// key after each tap. Needed because a single tap only advances ONE
    /// step through ALL enabled keyboards — if anything besides KITE and
    /// the default keyboard is enabled, one tap may land somewhere else
    /// entirely, not on KITE.
    private func switchToKITEKeyboard(in app: XCUIApplication) -> Bool {
        for _ in 0..<3 {
            let nextKeyboardButton = element(named: "Next keyboard", in: app)
            guard nextKeyboardButton.waitForExistence(timeout: 5) else { return false }
            nextKeyboardButton.tap()
            if element(named: "Q", in: app).waitForExistence(timeout: 3) { return true }
        }
        return false
    }

    func testTypingInSafariWithSimulatedTremorThenVerifyData() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()

        let interruption = addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(interruption) }

        let addressBar = safari.textFields["Address"]
        XCTAssertTrue(addressBar.waitForExistence(timeout: 5))
        addressBar.tap()
        // Deliberately NOT tapping anywhere else here — a prior extra tap
        // on the app landed on an unrelated element and stole focus away
        // from the address bar, dropping the keyboard before it could be
        // switched. Nothing else should touch the screen between focusing
        // the field and switching keyboards.

        XCTAssertTrue(switchToKITEKeyboard(in: safari), "Could not reach KITE keyboard after cycling — check only KITE + default keyboard are enabled in Settings")

        typeSentenceWithSimulatedTremor("the quick brown fox jumps", in: safari)

        let kite = XCUIApplication()
        kite.launch()

        if kite.buttons["Get Started"].waitForExistence(timeout: 3) {
            kite.buttons["Get Started"].tap()
            if kite.buttons["Continue"].waitForExistence(timeout: 3) { kite.buttons["Continue"].tap() }
            if kite.staticTexts["General"].waitForExistence(timeout: 3) { kite.staticTexts["General"].tap() }
            if kite.buttons["Skip calibration"].waitForExistence(timeout: 3) { kite.buttons["Skip calibration"].tap() }
        }

        let correctionsValue = kite.descendants(matching: .any)["correctionsThisWeekValue"]
        XCTAssertTrue(correctionsValue.waitForExistence(timeout: 5), "Dashboard did not show updated data after a real system-wide typing session")
    }

    func testTypingInMessagesWithSimulatedTremor() throws {
        let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        messages.launch()

        let firstConversation = messages.cells.firstMatch
        guard firstConversation.waitForExistence(timeout: 5) else {
            XCTFail("No existing conversation found in Messages — Simulator needs at least one seeded conversation.")
            return
        }
        firstConversation.tap()

        let composeField = messages.textViews.firstMatch.exists ? messages.textViews.firstMatch : messages.textFields.firstMatch
        guard composeField.waitForExistence(timeout: 5) else {
            XCTFail("Could not find a message compose field after opening a conversation.")
            return
        }
        composeField.tap()

        XCTAssertTrue(switchToKITEKeyboard(in: messages), "Could not reach KITE keyboard after cycling in Messages")

        typeSentenceWithSimulatedTremor("hello there friend", in: messages)
    }

    /// Uses REAL point-based offsets from each key's center — not a
    /// fraction of the key's own size, which was too small and self-
    /// contained to ever cross into a neighboring key. This range (roughly
    /// ±10pt) is comparable to the seeded scatter values already used
    /// elsewhere in the app (KeyOffset.seeded, 3-6.5pt) and occasionally
    /// large enough to spill into an adjacent key — which is the actual
    /// scenario CorrectionEngine.resolveTap exists to handle. NOTE: this
    /// still only sends a single discrete tap, not a continuous touch
    /// trajectory — real tremor's in-motion wobble isn't expressible via
    /// XCUITest's tap/press/drag primitives at all. The frequency-detection
    /// claim specifically is proven by testFrequencyEstimatorDetectsKnownOscillation
    /// in CorrectionEngineTests instead, which is the right tool for that job.
    private func typeSentenceWithSimulatedTremor(_ sentence: String, in app: XCUIApplication) {
        for character in sentence {
            let keyName = character == " " ? "space" : String(character).uppercased()
            let key = element(named: keyName, in: app)
            guard key.waitForExistence(timeout: 2) else { continue }
            let center = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let jitterX = Double.random(in: -10...10)
            let jitterY = Double.random(in: -10...10)
            let jittered = center.withOffset(CGVector(dx: jitterX, dy: jitterY))
            jittered.tap()
            usleep(useconds_t(Double.random(in: 100_000...250_000)))
        }
    }

    func testKITEGlobeButtonIsProperlyLabeled() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        let addressBar = safari.textFields["Address"]
        XCTAssertTrue(addressBar.waitForExistence(timeout: 5))
        addressBar.tap()
        XCTAssertTrue(switchToKITEKeyboard(in: safari), "Could not reach KITE keyboard")
        let switchKeyboardButton = element(named: "Switch Keyboard", in: safari)
        XCTAssertTrue(switchKeyboardButton.exists, "KITE's own globe button was not found or not properly labeled — check accessibilityLabel(for:) in KeyboardCoreView.swift actually includes a case for '🌐' and was rebuilt")
    }

    /// Uses a REAL (non-Demo) profile, learning from actual synthetic
    /// taps — not the canned Demo Mode profile — so whatever Dashboard/
    /// Heatmap show afterward is genuine learned data, suitable to
    /// actually screen-record. Jitter is deliberately large and
    /// consistently so (not just occasionally), to reliably cross into
    /// neighboring keys and produce visible, real corrections — this is
    /// the SEVERE end of plausible tremor, explicitly for producing a
    /// visible volume of real data, not a claim about a typical/average case.
    func testGenerateSubstantialRealDataForRecording() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()

        let addressBar = safari.textFields["Address"]
        XCTAssertTrue(addressBar.waitForExistence(timeout: 5))
        addressBar.tap()

        XCTAssertTrue(switchToKITEKeyboard(in: safari), "Could not reach KITE keyboard")

        let longText = "the quick brown fox jumps over the lazy dog pack my box with five dozen liquor jugs how vexingly quick daft zebras jump sphinx of black quartz judge my vow bright vixens jump dozy fowl quack the quick brown fox jumps again for good measure"

        typeSentenceWithSevereJitter(longText, in: safari)

        let kite = XCUIApplication()
        kite.launch()
        // Give the keyboard extension's viewWillDisappear a moment to
        // commit the session and save the profile before this test ends.
        sleep(2)
    }

    /// Consistently large jitter — magnitude drawn from 8-18pt in EACH
    /// axis (not a uniform range that often centers near zero), which
    /// reliably exceeds a typical key's half-width and triggers real
    /// scatter/directional corrections on most taps, from tap one, via
    /// the existing cold-start seeded variance.
    private func typeSentenceWithSevereJitter(_ sentence: String, in app: XCUIApplication) {
        for character in sentence {
            let keyName = character == " " ? "space" : String(character).uppercased()
            let key = element(named: keyName, in: app)
            guard key.waitForExistence(timeout: 2) else { continue }
            let center = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let jitterX = Double.random(in: 8...18) * (Bool.random() ? 1 : -1)
            let jitterY = Double.random(in: 8...18) * (Bool.random() ? 1 : -1)
            let jittered = center.withOffset(CGVector(dx: jitterX, dy: jitterY))
            jittered.tap()
            usleep(useconds_t(Double.random(in: 100_000...300_000)))
        }
    }

    /// FAST bulk data generation — routes through the DEBUG Quick Type
    /// tool rather than individual screen taps, so ~1000 characters takes
    /// roughly 2 minutes instead of 15-20. Uses the identical real
    /// correction pipeline underneath — just skips XCUITest's per-tap
    /// overhead, which exists to test discrete UI interaction, not
    /// something this bulk-data pass needs. Use this to quickly verify
    /// Dashboard/Heatmap/key-tinting actually respond to real accumulated
    /// data before recording the final, fully-authentic demo take below.
    /// NOTE: This test is currently skipped because the debug button
    /// accessibility in the keyboard extension is not reliably discoverable
    /// by XCUITest. Use testGenerateSubstantialRealDataForRecording instead
    /// for data generation verification.
    func testGenerateBulkDataViaDebugQuickType() throws {
        throw XCTSkip("Debug button not reliably accessible via XCUITest - use testGenerateSubstantialRealDataForRecording instead")
    }

    /// The FINAL, fully-authentic demo take — real screen taps, real
    /// severe jitter, moderate volume (not maximal) so the resulting
    /// Heatmap/Dashboard show a realistic MIX of well-learned and
    /// still-improving keys rather than everything uniformly maxed out,
    /// which reads as static rather than "watch it learn."
    func testFinalAuthenticDemoRecording() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        let addressBar = safari.textFields["Address"]
        XCTAssertTrue(addressBar.waitForExistence(timeout: 5))
        addressBar.tap()
        XCTAssertTrue(switchToKITEKeyboard(in: safari), "Could not reach KITE keyboard")
        typeSentenceWithSevereJitter(Self.demoRecordingText, in: safari)
    }

    /// ~950 characters, natural common English, not artificially repeated —
    /// gives a realistic letter-frequency distribution so common keys
    /// (E, T, A, O, I, N, S) show real progress while rarer ones stay
    /// visibly "still learning," the more convincing demo outcome.
    private static let bulkCorpus = """
    the weather today has been quite pleasant with clear skies and a gentle breeze from the west \
    my sister called this morning to ask about our plans for the weekend and whether we wanted to \
    join her family for dinner on saturday night at the new restaurant downtown near the old train \
    station i told her that sounded like a wonderful idea and that we would love to come along she \
    mentioned that her husband has been working really hard lately on a big project at his office \
    and could use a nice relaxing evening out with friends and family after such a stressful month \
    we talked for a while about how quickly the year has gone by and how the children have grown \
    so much since we last saw them her youngest just started learning to read and apparently loves \
    picking out books at the library every single week which made me smile thinking back to when \
    my own kids were that age and discovering stories for the very first time later that afternoon \
    i went for a long walk around the neighborhood and noticed several houses had already started \
    putting up decorations even though the holiday is still several weeks away it certainly does \
    bring a cheerful feeling to the whole street when everyone joins in together like that
    """

    /// Same corpus, used for the authentic screen-tap recording.
    private static let demoRecordingText = bulkCorpus
}
