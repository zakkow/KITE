import SwiftUI

fileprivate struct CalibrationCorrectionRecord {
    let baseKey: String
    let resolvedKey: String
    let timestamp: TimeInterval
}

/// SwiftUI wrapper around KeyboardCoreView for calibration. Wires taps to a
/// local text buffer and a REAL CorrectionEngine — calibration now actually
/// builds the user's starting motor profile from genuine tap coordinates,
/// instead of just recording which profile type they picked.
struct CalibrationKeyboardView: UIViewRepresentable {
    @Binding var typedText: String
    let correctionEngine: CorrectionEngine

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        fileprivate var lastCorrection: CalibrationCorrectionRecord?
        fileprivate var pendingRejectionCandidate: CalibrationCorrectionRecord?
        let rejectionWindow: TimeInterval = 5.0
    }

    func makeUIView(context: Context) -> KeyboardCoreView {
        let view = KeyboardCoreView()
        view.preferences = PreferencesStore.load()
        let coordinator = context.coordinator

        view.onControlKey = { key, timestamp in
            guard correctionEngine.shouldAcceptKeystroke(key: key, timestamp: timestamp) else { return }
            if key == "⌫" {
                if let last = coordinator.lastCorrection, timestamp - last.timestamp < coordinator.rejectionWindow {
                    coordinator.pendingRejectionCandidate = last
                    coordinator.lastCorrection = nil
                }
                if !typedText.isEmpty { typedText.removeLast() }
            } else if key == "space" {
                typedText += " "
                coordinator.pendingRejectionCandidate = nil
                coordinator.lastCorrection = nil
            }
        }

        view.onCorrectableKeyTapped = { baseKey, rawPoint, keyFrames, timestamp, detectedFrequencyHz in
            guard correctionEngine.shouldAcceptKeystroke(key: baseKey, timestamp: timestamp) else { return "" }

            let wordPosition: CorrectionContext = (typedText.last?.isLetter == true) ? .withinWord : .startOfWord
            let wordSoFar = typedText.components(separatedBy: .whitespacesAndNewlines).last ?? ""
            let result = correctionEngine.resolveTap(
                tappedKey: baseKey,
                rawPoint: rawPoint,
                wordSoFar: wordSoFar,
                wordPosition: wordPosition,
                interval: 0,
                isSensitiveField: false,
                allKeyFrames: keyFrames
            )

            // Implicit rejection: previous correction on this same key,
            // recently, now resolving differently — the user effectively
            // corrected KITE's correction.
            if let pending = coordinator.pendingRejectionCandidate,
               timestamp - pending.timestamp < coordinator.rejectionWindow,
               pending.baseKey == baseKey,
               result.resolvedKey != pending.resolvedKey {
                correctionEngine.markCorrectionRejected(key: pending.baseKey)
            }
            coordinator.pendingRejectionCandidate = nil

            let textToInsert: String
            if result.resolvedKey.lowercased() == "space" {
                textToInsert = " "
            } else if view.isLowercaseActive {
                textToInsert = result.resolvedKey.lowercased()
            } else {
                textToInsert = result.resolvedKey.uppercased()
            }
            typedText += textToInsert

            let didCorrect = result.didApplyDirectionalShift || result.didApplyScatterWidening || result.isManualOverride
            if didCorrect {
                view.flashCorrectionFeedback(for: baseKey)
                coordinator.lastCorrection = CalibrationCorrectionRecord(baseKey: baseKey, resolvedKey: result.resolvedKey, timestamp: timestamp)
            }

            let keyCenter = CGPoint(x: keyFrames[baseKey]?.midX ?? rawPoint.x, y: keyFrames[baseKey]?.midY ?? rawPoint.y)
            correctionEngine.recordTap(key: baseKey, rawPoint: rawPoint, keyCenter: keyCenter, detectedFrequencyHz: detectedFrequencyHz, accepted: true)

            view.learnedKeyOffsets = correctionEngine.currentKeyOffsets

            return textToInsert
        }

        // Explicit undo: swipe left reverts the last correction, same
        // rejectionWindow as the implicit path. No visual strip here (kept
        // out deliberately to limit scope on a screen users move through
        // quickly) — but the correction still gets properly unlearned.
        let swipeGesture = UISwipeGestureRecognizer()
        swipeGesture.direction = .left
        view.addGestureRecognizer(swipeGesture)
        // Using addAction-style handling via a target wrapper class:
        let handler = SwipeUndoHandler(coordinator: coordinator, typedText: Binding(get: { typedText }, set: { typedText = $0 }))
        swipeGesture.addTarget(handler, action: #selector(SwipeUndoHandler.handle))
        objc_setAssociatedObject(view, &AssociatedKeys.handler, handler, .OBJC_ASSOCIATION_RETAIN)

        return view
    }

    func updateUIView(_ uiView: KeyboardCoreView, context: Context) {}
}

private struct AssociatedKeys {
    static var handler: UInt8 = 0
}

private class SwipeUndoHandler: NSObject {
    let coordinator: CalibrationKeyboardView.Coordinator
    var typedText: Binding<String>

    init(coordinator: CalibrationKeyboardView.Coordinator, typedText: Binding<String>) {
        self.coordinator = coordinator
        self.typedText = typedText
    }

    @objc func handle() {
        guard let last = coordinator.lastCorrection else { return }
        if !typedText.wrappedValue.isEmpty { typedText.wrappedValue.removeLast() }
        typedText.wrappedValue += last.baseKey.lowercased()
        coordinator.lastCorrection = nil
    }
}
