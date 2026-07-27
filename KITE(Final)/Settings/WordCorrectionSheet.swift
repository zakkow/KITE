import SwiftUI

struct WordCorrectionSheet: View {
    var existingRule: CustomWordCorrectionRule?
    var onSave: (CustomWordCorrectionRule) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var typedWord: String
    @State private var correctedWord: String
    @State private var strictness: WordCorrectionStrictness
    @State private var context: WordCorrectionContext
    @State private var specificContextWord: String

    init(existingRule: CustomWordCorrectionRule? = nil, onSave: @escaping (CustomWordCorrectionRule) -> Void) {
        self.existingRule = existingRule
        self.onSave = onSave
        _typedWord = State(initialValue: existingRule?.typedWord ?? "")
        _correctedWord = State(initialValue: existingRule?.correctedWord ?? "")
        _strictness = State(initialValue: existingRule?.strictness ?? .exact)
        _context = State(initialValue: existingRule?.context ?? .anywhere)
        _specificContextWord = State(initialValue: existingRule?.specificContextWord ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if existingRule?.isAutoLearned == true {
                    Section {
                        Text("This correction was automatically learned from your typing habits. KITE will apply this silently once its confidence is high enough.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(content: {
                    TextField("Typed Word (e.g., lobe)", text: $typedWord)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }, footer: {
                    ScaledText("The typo you want to correct.", size: 12, relativeTo: .caption, color: .secondary)
                })

                Section(content: {
                    TextField("Correction (e.g., love)", text: $correctedWord)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }, footer: {
                    ScaledText("The word it should automatically change to.", size: 12, relativeTo: .caption, color: .secondary)
                })
                
                Section("Strictness") {
                    Picker("Strictness", selection: $strictness) {
                        ForEach(WordCorrectionStrictness.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    ScaledText(strictness == .exact
                        ? "Only corrects if you type this exact word."
                        : "Smartly detects plurals and suffixes (e.g. lobes -> loves, lobing -> loving).", size: 11, relativeTo: .caption, color: .secondary)
                }
                
                Section("Sentence Context") {
                    Picker("Context", selection: $context) {
                        ForEach(WordCorrectionContext.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.menu)
                    
                    if context == .precedingWord {
                        TextField("Preceding word (e.g. I)", text: $specificContextWord)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        ScaledText("Only corrects if the word right before it matches.", size: 11, relativeTo: .caption, color: .secondary)
                    } else if context == .followingWord {
                        TextField("Following word (e.g. morning)", text: $specificContextWord)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        ScaledText("Only corrects retroactively when you type this specific next word.", size: 11, relativeTo: .caption, color: .secondary)
                    } else if context == .anywhere {
                        ScaledText("Corrects the word anywhere in a sentence.", size: 11, relativeTo: .caption, color: .secondary)
                    } else if context == .startOfSentence {
                        ScaledText("Only corrects if it's the very first word in a sentence.", size: 11, relativeTo: .caption, color: .secondary)
                    }
                }
            }
            .navigationTitle(existingRule == nil ? "Add Correction" : "Edit Correction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTyped = typedWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let trimmedCorrected = correctedWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedContext = specificContextWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        
                        if !trimmedTyped.isEmpty && !trimmedCorrected.isEmpty {
                            let rule = CustomWordCorrectionRule(
                                typedWord: trimmedTyped,
                                correctedWord: trimmedCorrected,
                                strictness: strictness,
                                context: context,
                                specificContextWord: trimmedContext,
                                isAutoLearned: existingRule?.isAutoLearned ?? false,
                                confidence: existingRule?.confidence ?? 1
                            )
                            onSave(rule)
                            dismiss()
                        }
                    }
                    .disabled(typedWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || correctedWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
