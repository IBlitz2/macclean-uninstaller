import Foundation

struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let sizeBytes: Int64

    var id: URL { url }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
