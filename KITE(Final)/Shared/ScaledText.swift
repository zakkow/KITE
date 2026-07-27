import SwiftUI

/// Text that scales with the system's Dynamic Type accessibility setting
/// from a fixed base point size. Use this instead of
/// Text(...).font(.system(size:)) anywhere the design spec calls for a
/// specific pixel size — .font(.system(size:)) alone never scales at all,
/// which is what was silently breaking the accessibility promise made in
/// the UI/UX spec.
struct ScaledText: View {
    let content: String
    let weight: Font.Weight
    let color: Color
    @ScaledMetric private var scaledSize: CGFloat

    init(_ content: String, size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body, color: Color = .primary) {
        self.content = content
        self.weight = weight
        self.color = color
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    var body: some View {
        Text(content)
            .font(.system(size: scaledSize, weight: weight))
            .foregroundColor(color)
    }
}
