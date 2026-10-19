import AppKit
import SwiftUI

struct ContentView: View {
    @State private var apps: [InstalledApp] = []
    @State private var selectedApp: InstalledApp?
    @State private var relatedFiles: [RelatedFile] = []
    @State private var selectedFiles = Set<URL>()
    @State private var searchText = ""
    @State private var isScanning = false
    @State private var status = "Нажмите «Сканировать», чтобы найти приложения."
    @State private var showConfirmation = false
    @State private var pendingItems: [URL] = []
    @State private var pendingIsApp = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Найти приложение", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)

                Divider()

                if isScanning {
                    ProgressView("Сканирование…")
                        .padding()
                }

                List(selection: $selectedApp) {
                    ForEach(filteredApps) { app in
                        HStack(spacing: 10) {
                            appIcon(for: app)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name)
                                    .lineLimit(1)
                                Text(app.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(app)
                    }
                }
                .listStyle(.sidebar)

                Divider()
                Button {
                    scan()
                } label: {
                    Label("Сканировать", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(12)
                .disabled(isScanning)
            }
            .navigationTitle("MacClean")
            .frame(minWidth: 245)
        } detail: {
            detailView
        }
        .task { scan() }
        .onChange(of: selectedApp) { _, app in
            selectedFiles.removeAll()
            relatedFiles = []
            guard let app else { return }
            scanRelated(for: app)
        }
        .confirmationDialog(
            "Переместить выбранные элементы в Корзину?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Переместить в Корзину", role: .destructive) {
                performTrash()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будет обработано элементов: \(pendingItems.count). Проверьте выбранные пути перед продолжением.")
        }
        .alert("Не удалось выполнить действие", isPresented: $showError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let app = selectedApp {
                HStack(spacing: 14) {
                    appIcon(for: app, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2.weight(.semibold))
                        Text(app.bundleIdentifier ?? "Идентификатор приложения не найден")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        pendingItems = [app.url]
                        pendingIsApp = true
                        showConfirmation = true
                    } label: {
                        Label("Удалить приложение", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    Text("Возможные остатки")
                        .font(.headline)
                    Spacer()
                    Button("Повторить поиск") { scanRelated(for: app) }
                        .disabled(isScanning)
                }

                Text("Это только кандидаты, найденные по имени или идентификатору. Перед удалением проверьте каждый путь.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isScanning {
                    ProgressView("Поиск файлов…")
                } else if relatedFiles.isEmpty {
                    ContentUnavailableView(
                        "Остатки не найдены",
                        systemImage: "checkmark.circle",
                        description: Text("В проверенных пользовательских папках совпадений нет.")
                    )
                } else {
                    List(relatedFiles, selection: $selectedFiles) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.url.lastPathComponent)
                                .font(.body)
                            Text(file.displayPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            HStack {
                                Text(file.formattedSize)
                                Text("·")
                                Text(file.reason)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                    .listStyle(.inset)
                }

                HStack {
                    Text("\(relatedFiles.count) найдено · \(selectedFiles.count) выбрано")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Выбрать все") {
                        selectedFiles = Set(relatedFiles.map(\.url))
                    }
                    Button(role: .destructive) {
                        pendingItems = relatedFiles.map(\.url).filter { selectedFiles.contains($0) }
                        pendingIsApp = false
                        showConfirmation = true
                    } label: {
                        Label("Переместить в Корзину", systemImage: "trash")
                    }
                    .disabled(selectedFiles.isEmpty)
                }
            } else {
                ContentUnavailableView(
                    "Выберите приложение",
                    systemImage: "app.dashed",
                    description: Text("Список включает приложения из /Applications и ~/Applications.")
                )
            }

            Spacer(minLength: 0)
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .navigationTitle("Удаление приложений")
    }

    private func appIcon(for app: InstalledApp, size: CGFloat = 32) -> some View {
        let image = NSWorkspace.shared.icon(forFile: app.url.path)
        return Image(nsImage: image)
            .resizable()
            .frame(width: size, height: size)
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        status = "Сканирование папок приложений…"
        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppScanner.scanApplications()
            DispatchQueue.main.async {
                apps = found
                if let selectedApp, !found.contains(selectedApp) {
                    self.selectedApp = nil
                }
                isScanning = false
                status = "Найдено приложений: \(found.count). Системные каталоги не сканируются."
            }
        }
    }

    private func scanRelated(for app: InstalledApp) {
        isScanning = true
        status = "Поиск возможных остатков для \(app.name)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppScanner.relatedFiles(for: app)
            DispatchQueue.main.async {
                relatedFiles = found
                isScanning = false
                status = "Поиск завершён. Проверьте пути вручную перед удалением."
            }
        }
    }

    private func performTrash() {
        let items = pendingItems
        let isApp = pendingIsApp
        var failures: [String] = []
        for item in items {
            do {
                try TrashService.moveToTrash(item, isApplication: isApp)
            } catch {
                failures.append("\(item.path): \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
            showError = true
        }

        if isApp {
            selectedApp = nil
        } else if let app = selectedApp {
            scanRelated(for: app)
        }
        scan()
        status = "Обработано: \(items.count - failures.count) из \(items.count)."
    }
}
