import Foundation

enum GameStorageError: LocalizedError {
    case invalidJAR
    case manifestMissing
    case unsupportedFile
    case gameNotFound

    var errorDescription: String? {
        switch self {
        case .invalidJAR: "无法打开这个 JAR 文件。"
        case .manifestMissing: "JAR 中缺少 META-INF/MANIFEST.MF。"
        case .unsupportedFile: "JavaPocket 只支持 .jar Java ME 游戏。"
        case .gameNotFound: "游戏文件不存在。"
        }
    }
}

struct GameStorage {
    private let fileManager: FileManager
    let gamesDirectory: URL

    init(fileManager: FileManager = .default, documentsDirectory: URL? = nil) {
        self.fileManager = fileManager
        let documents = documentsDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        gamesDirectory = documents.appendingPathComponent("Games", isDirectory: true)
    }

    func prepare() throws {
        try fileManager.createDirectory(at: gamesDirectory, withIntermediateDirectories: true)
    }

    func directory(for gameID: String) -> URL {
        gamesDirectory.appendingPathComponent(gameID, isDirectory: true)
    }

    func jarURL(for game: GameRecord) -> URL {
        directory(for: game.id).appendingPathComponent("game.jar")
    }

    func metadataURL(for gameID: String) -> URL {
        directory(for: gameID).appendingPathComponent("metadata.json")
    }

    func iconURL(for game: GameRecord) -> URL? {
        guard let fileName = game.iconFileName else { return nil }
        return directory(for: game.id).appendingPathComponent(fileName)
    }

    func saveDirectory(for gameID: String) -> URL {
        directory(for: gameID).appendingPathComponent("save", isDirectory: true)
    }

    func rmsURL(for gameID: String) -> URL {
        saveDirectory(for: gameID).appendingPathComponent("rms.zip")
    }

    func controllerLayoutURL(for gameID: String) -> URL {
        saveDirectory(for: gameID).appendingPathComponent("controller-layout.json")
    }

    func hasSave(for gameID: String) -> Bool {
        fileManager.fileExists(atPath: rmsURL(for: gameID).path)
    }

    func loadGames() throws -> [GameRecord] {
        try prepare()
        let directories = try fileManager.contentsOfDirectory(
            at: gamesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return directories.compactMap { directory in
            let metadata = directory.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadata),
                  let record = try? decoder.decode(GameRecord.self, from: data)
            else { return nil }
            return record
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func write(_ game: GameRecord) throws {
        try fileManager.createDirectory(
            at: directory(for: game.id),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(game).write(to: metadataURL(for: game.id), options: .atomic)
    }

    func writeRMS(_ data: Data, for gameID: String) throws {
        let directory = saveDirectory(for: gameID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: rmsURL(for: gameID), options: .atomic)
    }

    func delete(gameID: String) throws {
        let url = directory(for: gameID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
