import SwiftUI

struct ScreenTitleHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            Image("KITELogo")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: Color.kiteAmber.opacity(0.20), radius: 4, x: 0, y: 2)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.kiteAmberDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}
