import Foundation

enum ControllerMode: String, Codable, CaseIterable, Identifiable {
    case nokia
    case joystick
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nokia: "Nokia 键盘"
        case .joystick: "摇杆"
        case .custom: "自定义"
        }
    }
}

struct GameRecord: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var vendor: String
    var version: String
    var profile: String
    var configuration: String
    var mainClass: String?
    var screenWidth: Int
    var screenHeight: Int
    var phoneType: String?
    var iconFileName: String?
    var jarFileName: String
    var isFavorite: Bool
    var importedAt: Date
    var lastPlayedAt: Date?
    var playCount: Int
    var controllerMode: ControllerMode

    var resolution: String { "\(screenWidth)x\(screenHeight)" }

    var javaVersion: String {
        [configuration, profile].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
