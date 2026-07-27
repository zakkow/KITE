import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let color: Color
    let rotation: Double
}

/// Brief celebratory screen after calibration finishes. Auto-dismisses
/// after 3 seconds — not a blocking screen, just a moment of positive
/// feedback before moving to the trial step.
struct CalibrationCompleteView: View {
    var onFinished: () -> Void
    @State private var pieces: [ConfettiPiece] = []
    @State private var fallProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors: [Color] = [.kiteAmber, .yellow, .kiteSuccess, .blue, .pink]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            GeometryReader { geo in
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: 8, height: 8)
                        .position(x: piece.x * geo.size.width, y: fallProgress * (geo.size.height + 40) - 20)
                        .rotationEffect(.degrees(piece.rotation * Double(fallProgress)))
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60)).foregroundColor(.kiteAmber)
                    .accessibilityHidden(true)
                ScaledText("Calibration Complete!", size: 28, weight: .bold, relativeTo: .largeTitle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Calibration complete")
        }
        .onAppear {
            pieces = (0..<40).map { _ in
                ConfettiPiece(x: .random(in: 0...1), color: colors.randomElement() ?? .kiteAmber, rotation: .random(in: 180...720))
            }
            if reduceMotion {
                fallProgress = 1.0
            } else {
                withAnimation(.easeIn(duration: 1.8)) { fallProgress = 1.0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { onFinished() }
        }
    }
}

#Preview { CalibrationCompleteView(onFinished: {}) }
