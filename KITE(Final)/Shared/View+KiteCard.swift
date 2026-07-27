import SwiftUI

/// App-wide card style modifier. Applies a systemGray6 background,
/// rounded corners, and a subtle colored border. The border color
/// shifts by role so the UI stays visually varied without oversaturation:
///
///   .kiteCard()             → warm amber (default, most containers)
///   .kiteCard(.stats)       → muted amber-orange (stat/metric chips)
///   .kiteCard(.info)        → teal-blue (informational / summary blocks)
///   .kiteCard(.warning)     → terracotta-red (alerts, resets, danger zones)
///   .kiteCard(.neutral)     → cool gray (read-only / baseline panels)
extension View {
    func kiteCard(_ role: KiteCardRole = .primary, radius: CGFloat = KiteRadius.large) -> some View {
        self
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(radius)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(role.borderColor, lineWidth: 1)
            )
    }
}

enum KiteCardRole {
    /// Most containers — warm amber tint, stays on-brand.
    case primary
    /// Stat/metric chips — slightly cooler amber so they don't compete.
    case stats
    /// Informational / profile summary blocks — blue-teal.
    case info
    /// Danger zones (reset, warnings) — terracotta.
    case warning
    /// Read-only / baseline panels — quiet gray.
    case neutral

    fileprivate var borderColor: Color {
        switch self {
        case .primary:  return Color.kiteAmber.opacity(0.30)
        case .stats:    return Color.kiteAmber.opacity(0.20)
        case .info:     return Color(red: 0.2, green: 0.55, blue: 0.75).opacity(0.30)
        case .warning:  return Color(red: 0.78, green: 0.25, blue: 0.22).opacity(0.30)
        case .neutral:  return Color(.systemGray3).opacity(0.50)
        }
    }
}
