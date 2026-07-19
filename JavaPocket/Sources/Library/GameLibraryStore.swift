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

    let storage: GameStorage
    private let importer: GameImportService

    init(storage: GameStorage = GameStorage()) {
        self.storage = storage
        importer = GameImportService(storage: storage)
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
        } catch {
            importError = error.localizedDescription
        }
    }

    func importURLs(_ urls: [URL]) {
        for url in urls {
            do {
                let game = try importer.importJAR(from: url)
                if let index = games.firstIndex(where: { $0.id == game.id }) {
                    games[index] = game
                } else {
                    games.append(game)
                }
            } catch {
                importError = error.localizedDescription
            }
        }
        games.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
