import SwiftUI

struct ManualCorrectionSheet: View {
    var existingRule: ManualCorrectionRule?
    var onSave: (ManualCorrectionRule) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fromKey: String
    @State private var toKey: String
    @State private var strictness: CorrectionStrictness
    @State private var context: CorrectionContext

    private let letters = (65...90).map { String(UnicodeScalar($0)!) }

    init(existingRule: ManualCorrectionRule? = nil, onSave: @escaping (ManualCorrectionRule) -> Void) {
        self.existingRule = existingRule
        self.onSave = onSave
        _fromKey = State(initialValue: existingRule?.fromKey ?? "A")
        _toKey = State(initialValue: existingRule?.toKey ?? "A")
        _strictness = State(initialValue: existingRule?.strictness ?? .always)
        _context = State(initialValue: existingRule?.context ?? .anywhere)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When I type") {
                    Picker("Key", selection: $fromKey) { ForEach(letters, id: \.self) { Text($0).tag($0) } }
                }
                Section("Always show instead") {
                    Picker("Key", selection: $toKey) { ForEach(letters, id: \.self) { Text($0).tag($0) } }
                }
                Section("How strict") {
                    Picker("Strictness", selection: $strictness) {
                        ForEach(CorrectionStrictness.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    ScaledText(strictness == .always
                        ? "This always overrides, even if KITE's own model is confident about this key."
                        : "This only applies when KITE's own model isn't confident yet — it won't override a correction it already trusts.", size: 11, relativeTo: .caption, color: .secondary)
                }
                Section("Where it applies") {
                    Picker("Context", selection: $context) {
                        ForEach(CorrectionContext.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    ScaledText("Never applies inside password, URL, or email fields, regardless of this setting.", size: 11, relativeTo: .caption, color: .secondary)
                }
            }
            .navigationTitle(existingRule == nil ? "Add Correction" : "Edit Correction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(ManualCorrectionRule(fromKey: fromKey, toKey: toKey, strictness: strictness, context: context))
                        dismiss()
                    }
                }
            }
        }
    }
}
