import Foundation

struct ControllerLayoutStore {
    let storage: GameStorage

    func load(gameID: String) -> ControllerLayout {
        let url = storage.controllerLayoutURL(for: gameID)
        guard let data = try? Data(contentsOf: url),
              let layout = try? JSONDecoder().decode(ControllerLayout.self, from: data)
        else { return .default }
        return layout
    }

    func save(_ layout: ControllerLayout, gameID: String) throws {
        let directory = storage.saveDirectory(for: gameID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(layout).write(
            to: storage.controllerLayoutURL(for: gameID),
            options: .atomic
        )
    }
}
