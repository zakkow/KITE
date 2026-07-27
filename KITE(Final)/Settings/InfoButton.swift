import SwiftUI

/// Info/help button using a diamond shape — the kite geometry — as the brand
/// motif. Subtle enough to not distract, on-brand enough to feel intentional.
struct InfoButton: View {
    let text: String
    @State private var showPopover = false

    var body: some View {
        Button { showPopover = true } label: {
            Image(systemName: "diamond.fill")
                .foregroundColor(.kiteAmber.opacity(0.75))
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.kiteAmber)
                    Text("KITE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.kiteAmber)
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 260)
            .presentationCompactAdaptation(.popover)
        }
    }
}
