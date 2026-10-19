import Foundation

enum TrashService {
    enum TrashError: LocalizedError {
        case unsafePath
        case missingItem

        var errorDescription: String? {
            switch self {
            case .unsafePath:
                return "Этот путь не разрешён для удаления приложением."
            case .missingItem:
                return "Файл уже не существует."
            }
        }
    }

    /// Moves a selected item to the macOS Trash. This does not permanently erase it.
    static func moveToTrash(_ url: URL, isApplication: Bool = false) throws {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let appRoots = ["/Applications/", "\(home)/Applications/"]
        let libraryRoots = [
            "\(home)/Library/Caches/",
            "\(home)/Library/Preferences/",
            "\(home)/Library/Application Support/",
            "\(home)/Library/Logs/",
            "\(home)/Library/Containers/",
            "\(home)/Library/Saved Application State/"
        ]

        let allowed = isApplication
            ? appRoots.contains { path.hasPrefix($0) } && path.hasSuffix(".app")
            : libraryRoots.contains { path.hasPrefix($0) }

        guard allowed else { throw TrashError.unsafePath }
        guard FileManager.default.fileExists(atPath: path) else { throw TrashError.missingItem }

        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}
