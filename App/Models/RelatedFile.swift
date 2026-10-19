import Foundation

struct RelatedFile: Identifiable, Hashable {
    let url: URL
    let reason: String
    let sizeBytes: Int64

    var id: URL { url }
    var displayPath: String { url.path }
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
