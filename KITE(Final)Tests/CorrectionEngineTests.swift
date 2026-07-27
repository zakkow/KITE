import XCTest
@testable import KITE_Final_

final class CorrectionEngineTests: XCTestCase {

    func testSymmetricScatterIsNotDirectionalDrift() {
        var offset = KeyOffset(key: "Q")
        let deltas: [(CGFloat, CGFloat)] = [(5,5),(-5,-5),(5,-5),(-5,5),(4,4),(-4,-4)]
        for (dx, dy) in deltas {
            offset.averageDeltaX = (offset.averageDeltaX * 0.7) + (dx * 0.3)
            offset.averageDeltaY = (offset.averageDeltaY * 0.7) + (dy * 0.3)
            offset.varianceX = (offset.varianceX * 0.7) + (abs(dx - offset.averageDeltaX) * 0.3)
            offset.varianceY = (offset.varianceY * 0.7) + (abs(dy - offset.averageDeltaY) * 0.3)
            offset.sampleCount += 1
        }
        XCTAssertFalse(offset.isDirectionalDrift, "Symmetric oscillation should not be classified as directional drift")
    }

    func testConsistentBiasIsDirectionalDrift() {
        var offset = KeyOffset(key: "Q")
        for _ in 0..<15 {
            let dx: CGFloat = 12
            let dy: CGFloat = -11
            offset.averageDeltaX = (offset.averageDeltaX * 0.7) + (dx * 0.3)
            offset.averageDeltaY = (offset.averageDeltaY * 0.7) + (dy * 0.3)
            offset.varianceX = (offset.varianceX * 0.7) + (abs(dx - offset.averageDeltaX) * 0.3)
            offset.varianceY = (offset.varianceY * 0.7) + (abs(dy - offset.averageDeltaY) * 0.3)
            offset.sampleCount += 1
        }
        XCTAssertTrue(offset.isDirectionalDrift, "Consistent one-directional bias should be classified as directional drift")
    }

    func testSeededValuesMatchClinicalGroundingTable() {
        XCTAssertEqual(KeyOffset.seeded(for: "Q", profileType: .tremor).varianceX, 6.5)
        XCTAssertEqual(KeyOffset.seeded(for: "Q", profileType: .spasticity).varianceX, 3.0)
        XCTAssertEqual(KeyOffset.seeded(for: "Q", profileType: .general).varianceX, 5.0)
        let notSure = KeyOffset.seeded(for: "Q", profileType: .notSure)
        XCTAssertEqual(notSure.varianceX, 4.0)
        XCTAssertEqual(notSure.confidence, 0.2)
    }

    func testMarkCorrectionRejectedLowersAcceptanceRate() {
        let engine = CorrectionEngine(profile: MotorProfile.fresh(profileType: .general), preferences: .default)
        for _ in 0..<4 {
            engine.recordTap(key: "Q", rawPoint: CGPoint(x: 0, y: 0), keyCenter: CGPoint(x: 0, y: 0), accepted: true)
        }
        let before = engine.debugProfile.keyOffsets["Q"]!.acceptanceRate
        engine.markCorrectionRejected(key: "Q")
        let after = engine.debugProfile.keyOffsets["Q"]!.acceptanceRate
        XCTAssertLessThan(after, before, "Rejecting a correction should lower that key's acceptance rate")
    }

    func testThreeConsecutiveRejectionsResetsToSeed() {
        let engine = CorrectionEngine(profile: MotorProfile.fresh(profileType: .tremor), preferences: .default)
        for _ in 0..<5 {
            engine.recordTap(key: "Q", rawPoint: CGPoint(x: 20, y: 20), keyCenter: CGPoint(x: 0, y: 0), accepted: true)
        }
        XCTAssertGreaterThan(engine.debugProfile.keyOffsets["Q"]!.sampleCount, 0)
        engine.markCorrectionRejected(key: "Q")
        engine.markCorrectionRejected(key: "Q")
        engine.markCorrectionRejected(key: "Q")
        let seeded = KeyOffset.seeded(for: "Q", profileType: .tremor)
        XCTAssertEqual(engine.debugProfile.keyOffsets["Q"]!.varianceX, seeded.varianceX, "Third consecutive rejection should reset this key back to its seeded default")
        XCTAssertEqual(engine.debugProfile.keyOffsets["Q"]!.sampleCount, 0)
    }

    func testFrequencyEstimatorDetectsKnownOscillation() {
        var trajectory: [(point: CGPoint, timestamp: TimeInterval)] = []
        let duration = 0.2
        let frequency = 6.0
        let sampleCount = 20
        for i in 0..<sampleCount {
            let t = duration * Double(i) / Double(sampleCount - 1)
            let x = CGFloat(sin(2 * .pi * frequency * t)) * 5
            trajectory.append((CGPoint(x: x, y: 0), t))
        }
        let result = TremorFrequencyEstimator.estimateFrequencyHz(from: trajectory)
        XCTAssertNotNil(result)
        if let result { XCTAssertEqual(result, frequency, accuracy: 2.0) }
    }

    func testFrequencyEstimatorReturnsNilForStillTouch() {
        let trajectory: [(point: CGPoint, timestamp: TimeInterval)] = [
            (CGPoint(x: 0, y: 0), 0.0),
            (CGPoint(x: 0, y: 0), 0.02),
            (CGPoint(x: 0, y: 0), 0.04)
        ]
        XCTAssertNil(TremorFrequencyEstimator.estimateFrequencyHz(from: trajectory))
    }

    func testLinguisticGateBlocksMyBecomingMt() {
        let gate = LinguisticPlausibilityGate()
        XCTAssertFalse(gate.shouldAllowCorrection(wordSoFar: "m", raw: "y", corrected: "t"))
    }

    func testLinguisticGateBlocksNameBecomingNonWord() {
        let gate = LinguisticPlausibilityGate()
        XCTAssertFalse(gate.shouldAllowCorrection(wordSoFar: "nam", raw: "e", corrected: "r"))
    }

    func testLinguisticGateDoesNotOverBlock() {
        let gate = LinguisticPlausibilityGate()
        XCTAssertTrue(gate.shouldAllowCorrection(wordSoFar: "ca", raw: "r", corrected: "t"))
    }

    func testLinguisticGateAllowsAmbiguousInProgressWords() {
        let gate = LinguisticPlausibilityGate()
        XCTAssertTrue(gate.shouldAllowCorrection(wordSoFar: "tha", raw: "n", corrected: "t"))
    }
}
