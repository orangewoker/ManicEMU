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

struct GameStorage: @unchecked Sendable {
    private let fileManager: FileManager
    let documentsDirectory: URL
    let gamesDirectory: URL

    init(fileManager: FileManager = .default, documentsDirectory: URL? = nil) {
        self.fileManager = fileManager
        let documents = documentsDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.documentsDirectory = documents
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

    func looseJARs() throws -> [URL] {
        try prepare()
        return try [documentsDirectory, gamesDirectory]
            .flatMap { directory in
                try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            }
            .filter { url in
                guard url.pathExtension.lowercased() == "jar" else { return false }
                return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
    }

    /// Copies a document-picker URL into the app container while the picker
    /// security scope is still valid. Files/iCloud may revoke the original URL
    /// as soon as the picker completion handler returns.
    func stagePickedJAR(at sourceURL: URL) throws -> URL {
        guard sourceURL.pathExtension.lowercased() == "jar" else {
            throw GameStorageError.unsupportedFile
        }

        try prepare()
        let stagingDirectory = gamesDirectory.appendingPathComponent(
            ".picker-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let stagedURL = stagingDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: .withoutChanges,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try fileManager.copyItem(at: coordinatedURL, to: stagedURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            try? fileManager.removeItem(at: stagingDirectory)
            throw coordinationError
        }
        if let copyError {
            try? fileManager.removeItem(at: stagingDirectory)
            throw copyError
        }
        return stagedURL
    }

    func consumeLooseJAR(at url: URL) throws {
        let parent = url.deletingLastPathComponent().standardizedFileURL
        let allowedParents = [documentsDirectory, gamesDirectory].map(\.standardizedFileURL)
        if allowedParents.contains(parent), fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            return
        }

        // Picker imports live in Games/.picker-UUID/original-name.jar so the
        // original filename survives in metadata. Remove the hidden directory.
        let stagingRoot = parent.deletingLastPathComponent().standardizedFileURL
        if stagingRoot == gamesDirectory.standardizedFileURL,
           parent.lastPathComponent.hasPrefix(".picker-") {
            try fileManager.removeItem(at: parent)
        }
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
