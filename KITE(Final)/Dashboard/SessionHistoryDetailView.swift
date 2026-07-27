import SwiftUI

struct SessionHistoryDetailView: View {
    let sessions: [SessionData]

    var body: some View {
        List(sessions.reversed(), id: \.id) { session in
            NavigationLink(destination: SessionDetailView(session: session)) {
                HStack {
                    Text("\(session.date.formatted(date: .omitted, time: .shortened)) · \(session.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14))
                    Spacer()
                    Text(session.correctionsApplied > 0
                        ? "\(session.correctionsApplied) corrections · \(Int(session.accuracyRate * 100))% accepted"
                        : "\(session.totalKeystrokes) taps · no corrections needed")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Full History")
    }
}
