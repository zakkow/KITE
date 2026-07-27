import SwiftUI

struct HelpTopic: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct HelpView: View {
    private let topics: [HelpTopic] = [
        HelpTopic(question: "Why did KITE change a letter I typed?", answer: "KITE learned your tap pattern for that key and corrected it. Swipe left on the keyboard to undo any correction."),
        HelpTopic(question: "What's the difference between Directional and Widened?", answer: "Directional means KITE shifts your tap in a consistent direction. Widened means it accepts a wider area around a key because your taps scatter rather than drift one way."),
        HelpTopic(question: "How do I add my own correction rule?", answer: "Settings → Corrections → Add Correction — choose which key should always show a different letter."),
        HelpTopic(question: "Why does a key look amber on the keyboard?", answer: "Darker amber means KITE is more confident about that key's pattern. No color yet means not enough data."),
        HelpTopic(question: "Is any of my data sent anywhere?", answer: "No. Everything stays on your device. See Settings → Privacy Details.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Branded header
                VStack(spacing: 12) {
                    Image("KITELogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.kiteAmber.opacity(0.25), radius: 8, x: 0, y: 3)
                    Text("How KITE Works")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.kiteAmberDark)
                    Text("Everything you need to know about your adaptive keyboard.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .padding(.horizontal)

                Divider().padding(.horizontal)

                // FAQ list
                VStack(spacing: 0) {
                    ForEach(topics) { topic in
                        DisclosureGroup {
                            Text(topic.answer)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.kiteAmber)
                                    .accessibilityHidden(true)
                                Text(topic.question)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        Divider().padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}
