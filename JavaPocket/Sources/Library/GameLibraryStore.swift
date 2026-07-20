import Foundation

@MainActor
final class GameLibraryStore: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case favorites
        case recent

        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "全部"
            case .favorites: "收藏"
            case .recent: "最近"
            }
        }
    }

    @Published private(set) var games: [GameRecord] = []
    @Published var searchText = ""
    @Published var filter: Filter = .all
    @Published var isGrid = true
    @Published var importError: String?
    @Published var importNotice: String?
    @Published private(set) var isImporting = false

    let storage: GameStorage

    init(storage: GameStorage = GameStorage()) {
        self.storage = storage
        reload()
    }

    var visibleGames: [GameRecord] {
        let filtered: [GameRecord]
        switch filter {
        case .all:
            filtered = games
        case .favorites:
            filtered = games.filter(\.isFavorite)
        case .recent:
            filtered = games.filter { $0.lastPlayedAt != nil }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return filtered
        }
        return filtered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.vendor.localizedCaseInsensitiveContains(searchText)
                || $0.jarFileName.localizedCaseInsensitiveContains(searchText)
        }
    }

    func reload() {
        do {
            games = try storage.loadGames()
            let looseJARs = try storage.looseJARs()
            if !looseJARs.isEmpty {
                importURLs(looseJARs)
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty, !isImporting else { return }
        isImporting = true
        importError = nil
        importNotice = nil

        let storage = storage
        Task {
            var importedCount = 0
            for url in urls {
                do {
                    let game = try await Task.detached(priority: .userInitiated) {
                        try GameImportService(storage: storage).importJAR(from: url)
                    }.value
                    if let index = games.firstIndex(where: { $0.id == game.id }) {
                        games[index] = game
                    } else {
                        games.append(game)
                    }
                    try? storage.consumeLooseJAR(at: url)
                    importedCount += 1
                } catch {
                    importError = "\(url.lastPathComponent)：\(error.localizedDescription)"
                }
            }

            games.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if importedCount > 0 {
                filter = .all
                searchText = ""
                if importError == nil {
                    importNotice = importedCount == 1
                        ? "游戏已加入 J2ME Games。"
                        : "已导入 \(importedCount) 个游戏。"
                }
            }
            isImporting = false
        }
    }

    func toggleFavorite(_ game: GameRecord) {
        update(game.id) { $0.isFavorite.toggle() }
    }

    func markPlayed(_ game: GameRecord) {
        update(game.id) {
            $0.lastPlayedAt = Date()
            $0.playCount += 1
        }
    }

    func setControllerMode(_ mode: ControllerMode, for game: GameRecord) {
        update(game.id) { $0.controllerMode = mode }
    }

    func delete(_ game: GameRecord) {
        do {
            try storage.delete(gameID: game.id)
            games.removeAll { $0.id == game.id }
        } catch {
            importError = error.localizedDescription
        }
    }

    func record(for id: String) -> GameRecord? {
        games.first { $0.id == id }
    }

    private func update(_ id: String, mutation: (inout GameRecord) -> Void) {
        guard let index = games.firstIndex(where: { $0.id == id }) else { return }
        mutation(&games[index])
        do {
            try storage.write(games[index])
        } catch {
            importError = error.localizedDescription
        }
    }
}
