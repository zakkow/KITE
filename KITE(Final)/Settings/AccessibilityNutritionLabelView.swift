import SwiftUI

/// A "nutrition label" style privacy summary: what data KITE collects,
/// where it lives, and how it's used. No account, no cloud, no third parties.
struct AccessibilityNutritionLabelView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScaledText("Privacy Details", size: 22, weight: .bold, relativeTo: .title2)
                    .padding(.bottom, 8)

                Label("Data Collection", systemImage: "info.circle")
                    .font(.headline)
                ScaledText("KITE records which keys you tap, where on the key you tapped, and whether a correction was applied — this builds the model that personalizes corrections to your hand. It does not store your typed text as a document or transcript, but the recorded tap sequence could be used to reconstruct approximately what you typed. This data never leaves your device.", size: 17, relativeTo: .body)

                Label("Storage Location", systemImage: "internaldrive")
                    .font(.headline)
                ScaledText("All data lives in your device's app group container. No account, no cloud, no third-party services.", size: 17, relativeTo: .body)

                Label("Data Use", systemImage: "gear")
                    .font(.headline)
                ScaledText("Your typing data is used exclusively to personalize the keyboard's correction model for your specific motor pattern. It is never shared with anyone.", size: 17, relativeTo: .body)

                Label("Data Retention", systemImage: "clock")
                    .font(.headline)
                ScaledText("Session history is kept for up to 30 days. Your motor profile persists until you delete it manually via Settings → Clear All Data.", size: 17, relativeTo: .body)

                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.headline)
                ScaledText("You can export a plain-text summary of your profile via Settings → Privacy → Export Report. This uses the system share sheet — you choose the destination (AirDrop, Messages, saving to Files, etc.).", size: 17, relativeTo: .body)

                Label("Deletion", systemImage: "trash")
                    .font(.headline)
                ScaledText("Settings → Data → Clear All Data permanently deletes everything KITE has learned and all saved preferences. This cannot be undone.", size: 17, relativeTo: .body)
            }
            .padding()
        }
        .navigationTitle("Privacy")
    }
}
