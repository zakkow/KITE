import SwiftUI

/// Wraps the system share sheet (which includes AirDrop automatically) for
/// exporting a plain-text report. No server, no account — you choose the
/// destination via the system share sheet (AirDrop, Messages, Files, etc.) —
/// KITE itself never transmits anything.
struct ShareSheetWrapper: View {
    let text: String
    var body: some View {
        ShareLink(item: text) {
            Label("Share Report", systemImage: "square.and.arrow.up")
        }
        .padding()
    }
}
