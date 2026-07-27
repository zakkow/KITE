import XCTest

final class SyntheticTremorUITests: XCTestCase {

    /// Same frequency range as CorrectionEngineTests and doc 06's citation
    /// (Deuschl et al. 1998, 4-11 Hz) — this is a real testing harness
    /// against the actual app, not a roleplay or imagined behavior.
    func testFullOnboardingWithSimulatedTremor() {
        let app = XCUIApplication()
        app.launch()

        // Onboarding — plain text button matching, no tremor needed here,
        // this is just navigation.
        app.buttons["Get Started"].tap()
        app.buttons["Continue"].tap()
        app.staticTexts["Tremor"].tap()
        app.buttons["Continue to Calibration"].tap()

        let sentence = "the quick brown fox jumps over the lazy dog"
        for character in sentence {
            let key = character == " " ? "space" : String(character).uppercased()
            let button = app.buttons[key]
            guard button.waitForExistence(timeout: 2) else { continue }

            // Tap with a small offset simulating tremor scatter — goes
            // through REAL touch handling, not a mock.
            let offsetX = Double.random(in: -0.15...0.15)
            let offsetY = Double.random(in: -0.15...0.15)
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + offsetX, dy: 0.5 + offsetY)).tap()

            usleep(useconds_t(Double.random(in: 100_000...250_000))) // 4-11Hz-ish pacing between taps
        }

        // Reaching this line without a crash/hang is the pass condition for
        // this first version — inspecting the resulting profile data is the
        // next iteration once this baseline run is confirmed reliable.
    }
}
