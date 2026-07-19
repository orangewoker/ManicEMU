import CryptoKit
import Foundation

struct GameImportService {
    let storage: GameStorage
    private let parser = JARManifestParser()
    private let fileManager = FileManager.default

    func importJAR(from sourceURL: URL) throws -> GameRecord {
        guard sourceURL.pathExtension.lowercased() == "jar" else {
            throw GameStorageError.unsupportedFile
        }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let jarData = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        let identifier = SHA256.hash(data: jarData).map { String(format: "%02x", $0) }.joined()
        let destination = storage.directory(for: identifier)
        if fileManager.fileExists(atPath: destination.path),
           let existingData = try? Data(contentsOf: storage.metadataURL(for: identifier)) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let existing = try? decoder.decode(GameRecord.self, from: existingData) {
                return existing
            }
        }

        let manifest = try parser.parse(url: sourceURL)
        let size = manifest.screenSize
        let temporary = storage.gamesDirectory.appendingPathComponent(
            ".import-\(UUID().uuidString)",
            isDirectory: true
        )
        try storage.prepare()
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)

        do {
            try jarData.write(to: temporary.appendingPathComponent("game.jar"), options: .atomic)
            let iconFileName: String?
            if let icon = manifest.iconData, !icon.isEmpty {
                iconFileName = "icon.png"
                try icon.write(to: temporary.appendingPathComponent("icon.png"), options: .atomic)
            } else {
                iconFileName = nil
            }

            let record = GameRecord(
                id: identifier,
                name: manifest.name,
                vendor: manifest.vendor,
                version: manifest.version,
                profile: manifest.profile,
                configuration: manifest.configuration,
                mainClass: manifest.mainClass,
                screenWidth: size.width,
                screenHeight: size.height,
                phoneType: manifest.phoneType,
                iconFileName: iconFileName,
                jarFileName: sourceURL.lastPathComponent,
                isFavorite: false,
                importedAt: Date(),
                lastPlayedAt: nil,
                playCount: 0,
                controllerMode: .nokia
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(record).write(
                to: temporary.appendingPathComponent("metadata.json"),
                options: .atomic
            )
            try fileManager.moveItem(at: temporary, to: destination)
            return record
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }
}
