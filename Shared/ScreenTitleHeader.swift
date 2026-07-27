import SwiftUI

struct ScreenTitleHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.kiteAmberDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}
