import SwiftUI
import UniformTypeIdentifiers

struct KiteExportBundle: Codable {
    var profile: MotorProfile
    var preferences: UserPreferences
    var sessionHistory: [SessionData]? = nil
    var baselineSnapshot: ProfileSnapshot? = nil
    var explainabilityLog: [ExplainabilityLogEntry]? = nil
    var inputStyle: String? = nil
    var exportedAt: Date = Date()
}

struct KiteProfileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json]
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
