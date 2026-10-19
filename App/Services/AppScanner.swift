import AppKit
import Foundation

enum AppScanner {
    static func scanApplications() -> [InstalledApp] {
        let fm = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var results: [InstalledApp] = []
        var seen = Set<String>()

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries where url.pathExtension == "app" {
                guard seen.insert(url.standardizedFileURL.path).inserted else { continue }
                let bundle = Bundle(url: url)
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let identifier = bundle?.bundleIdentifier
                results.append(
                    InstalledApp(
                        url: url,
                        name: name,
                        bundleIdentifier: identifier,
                        sizeBytes: directorySize(at: url)
                    )
                )
            }
        }

        return results.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func relatedFiles(for app: InstalledApp) -> [RelatedFile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let name = app.url.deletingPathExtension().lastPathComponent
        let bundleID = app.bundleIdentifier

        let roots = [
            library.appendingPathComponent("Caches", isDirectory: true),
            library.appendingPathComponent("Preferences", isDirectory: true),
            library.appendingPathComponent("Application Support", isDirectory: true),
            library.appendingPathComponent("Logs", isDirectory: true),
            library.appendingPathComponent("Containers", isDirectory: true),
            library.appendingPathComponent("Saved Application State", isDirectory: true)
        ]

        var candidates: [URL] = []
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in entries {
                let lower = item.lastPathComponent.lowercased()
                let nameMatch = !name.isEmpty && lower.contains(name.lowercased())
                let idMatch = bundleID.map { lower == $0.lowercased() || lower.hasPrefix($0.lowercased() + ".") } ?? false
                if nameMatch || idMatch {
                    candidates.append(item)
                }
            }
        }

        return candidates
            .filter { !$0.path.isEmpty }
            .map { RelatedFile(url: $0, reason: "Совпадение имени или идентификатора приложения", sizeBytes: directorySize(at: $0)) }
            .sorted { $0.url.path < $1.url.path }
    }

    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values?.fileSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
