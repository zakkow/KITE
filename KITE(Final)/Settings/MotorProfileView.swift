import SwiftUI

struct MotorProfileView: View {
    @State private var profile: MotorProfile = MotorProfile()
    
    var body: some View {
        Form {
            Section(header: Text("Motor Profile Overview"), footer: Text("KITE continuously learns your physical typing habits to silently correct missed keys.")) {
                HStack {
                    Text("Total Learned Keys")
                    Spacer()
                    Text("\(profile.keyOffsets.count)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Profile Type")
                    Spacer()
                    Text(profile.profileType.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Learned Spatial Shifts")) {
                if profile.keyOffsets.isEmpty {
                    Text("No spatial shifts learned yet. Keep typing!")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(profile.keyOffsets.keys.sorted(), id: \.self) { key in
                            if let offset = profile.keyOffsets[key], offset.sampleCount > 5 {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(key)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(Int(offset.confidence * 100))% Confident")
                                            .font(.caption)
                                            .foregroundColor(offset.confidence > 0.8 ? .green : .orange)
                                    }
                                    
                                    Text("Shifted X: \(String(format: "%.1f", offset.averageDeltaX)), Y: \(String(format: "%.1f", offset.averageDeltaY))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteOffsets)
                    }
                }
            }
            
            if !profile.keyOffsets.isEmpty {
                Section {
                    Button(role: .destructive) {
                        resetProfile()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Motor Profile")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Motor Profile")
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        if let data = SharedStore.getSharedData(forKey: SharedStore.Keys.motorProfile),
           let decoded = try? JSONDecoder().decode(MotorProfile.self, from: data) {
            self.profile = decoded
        }
    }
    
    private func deleteOffsets(at offsets: IndexSet) {
        let keys = profile.keyOffsets.keys.sorted()
        for index in offsets {
            let key = keys[index]
            profile.keyOffsets.removeValue(forKey: key)
        }
        saveProfile()
    }
    
    private func resetProfile() {
        profile.keyOffsets.removeAll()
        saveProfile()
    }
    
    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            SharedStore.setSharedData(encoded, forKey: SharedStore.Keys.motorProfile)
        }
    }
}

struct MotorProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MotorProfileView()
        }
    }
}
