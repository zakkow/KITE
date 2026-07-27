import SwiftUI

enum VocabularyType {
    case whitelisted
    case blacklisted
}

struct LearnedVocabularyManagerView: View {
    @State private var whitelistedWords: [String] = SharedStore.whitelistedWords
    @State private var blacklistedWords: [String] = SharedStore.blacklistedWords
    @State private var searchText: String = ""

    // Edit modal states
    @State private var editingWord: String? = nil
    @State private var editingType: VocabularyType = .whitelisted
    @State private var editText: String = ""
    @State private var showEditAlert = false

    // Add modal states
    @State private var showAddAlert = false
    @State private var newWordText: String = ""
    @State private var newWordType: VocabularyType = .whitelisted

    var filteredBlacklist: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return blacklistedWords
        }
        return blacklistedWords.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredWhitelist: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return whitelistedWords
        }
        return whitelistedWords.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Form {
            Section(header: Text("Blacklisted Words (Vetoed Corrections)").foregroundColor(.red)) {
                if filteredBlacklist.isEmpty {
                    Text(searchText.isEmpty ? "No blacklisted words yet." : "No matching blacklisted words.")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(filteredBlacklist, id: \.self) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("\"\(word)\"").font(.body).foregroundColor(.primary)
                                    Text("Blacklisted")
                                        .font(.caption2).fontWeight(.semibold)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.red.opacity(0.12)).foregroundColor(.red)
                                        .cornerRadius(4)
                                }
                                Text("Blocked from auto-corrections").font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                startEditing(word: word, type: .blacklisted)
                            } label: {
                                Image(systemName: "pencil").foregroundColor(.kiteAmber)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .accessibilityLabel("Edit blacklisted word \(word)")

                            Button(role: .destructive) {
                                deleteWord(word: word, type: .blacklisted)
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete blacklisted word \(word)")
                        }
                    }
                }
                Button {
                    openAddModal(type: .blacklisted)
                } label: {
                    Label("Add Blacklisted Word", systemImage: "plus.circle")
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("Whitelisted Words (Custom Vocabulary)").foregroundColor(.kiteAmberDark)) {
                if filteredWhitelist.isEmpty {
                    Text(searchText.isEmpty ? "No custom whitelisted words yet." : "No matching custom words.")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(filteredWhitelist, id: \.self) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("\"\(word)\"").font(.body).foregroundColor(.primary)
                                    Text("Whitelisted")
                                        .font(.caption2).fontWeight(.semibold)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.kiteAmber.opacity(0.12)).foregroundColor(.kiteAmber)
                                        .cornerRadius(4)
                                }
                                Text("Recognized valid word / acronym").font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                startEditing(word: word, type: .whitelisted)
                            } label: {
                                Image(systemName: "pencil").foregroundColor(.kiteAmber)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .accessibilityLabel("Edit whitelisted word \(word)")

                            Button(role: .destructive) {
                                deleteWord(word: word, type: .whitelisted)
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete whitelisted word \(word)")
                        }
                    }
                }
                Button {
                    openAddModal(type: .whitelisted)
                } label: {
                    Label("Add Whitelisted Word", systemImage: "plus.circle")
                        .foregroundColor(.kiteAmber)
                }
            }
        }
        .navigationTitle("Learned Vocabulary")
        .searchable(text: $searchText, prompt: "Search learned words...")
        .alert("Edit Word", isPresented: $showEditAlert) {
            TextField("Word", text: $editText)
            Button("Save") {
                commitEdit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Update the spelling or wording for this entry.")
        }
        .alert(newWordType == .blacklisted ? "Add Blacklisted Word" : "Add Whitelisted Word", isPresented: $showAddAlert) {
            TextField("Word or phrase", text: $newWordText)
            Button("Add") {
                commitAdd()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(newWordType == .blacklisted ? "KITE will never auto-correct this word." : "KITE will always recognize this word as valid.")
        }
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        whitelistedWords = SharedStore.whitelistedWords
        blacklistedWords = SharedStore.blacklistedWords
    }

    private func deleteWord(word: String, type: VocabularyType) {
        let target = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if type == .blacklisted {
            var current = SharedStore.blacklistedWords
            current.removeAll { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == target }
            SharedStore.blacklistedWords = current
            blacklistedWords = current
        } else {
            var current = SharedStore.whitelistedWords
            current.removeAll { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == target }
            SharedStore.whitelistedWords = current
            whitelistedWords = current
        }
    }

    private func startEditing(word: String, type: VocabularyType) {
        editingWord = word
        editingType = type
        editText = word
        showEditAlert = true
    }

    private func commitEdit() {
        guard let oldWord = editingWord else { return }
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }

        if editingType == .blacklisted {
            var current = SharedStore.blacklistedWords
            if let idx = current.firstIndex(of: oldWord) {
                current[idx] = trimmed
            }
            SharedStore.blacklistedWords = current
            blacklistedWords = current
        } else {
            var current = SharedStore.whitelistedWords
            if let idx = current.firstIndex(of: oldWord) {
                current[idx] = trimmed
            }
            SharedStore.whitelistedWords = current
            whitelistedWords = current
        }
    }

    private func openAddModal(type: VocabularyType) {
        newWordType = type
        newWordText = ""
        showAddAlert = true
    }

    private func commitAdd() {
        let trimmed = newWordText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }

        if newWordType == .blacklisted {
            var current = SharedStore.blacklistedWords
            if !current.contains(trimmed) {
                current.append(trimmed)
                SharedStore.blacklistedWords = current
                blacklistedWords = current
            }
        } else {
            var current = SharedStore.whitelistedWords
            if !current.contains(trimmed) {
                current.append(trimmed)
                SharedStore.whitelistedWords = current
                whitelistedWords = current
            }
        }
    }
}

#Preview {
    NavigationStack {
        LearnedVocabularyManagerView()
    }
}
