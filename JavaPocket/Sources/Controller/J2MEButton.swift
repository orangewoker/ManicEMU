import Foundation

enum J2MEButton: String, Codable, CaseIterable, Identifiable {
    case up
    case down
    case left
    case right
    case fire
    case num0
    case num1
    case num2
    case num3
    case num4
    case num5
    case num6
    case num7
    case num8
    case num9
    case star
    case pound
    case softkeyLeft
    case softkeyRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        case .fire: "OK"
        case .num0: "0"
        case .num1: "1"
        case .num2: "2"
        case .num3: "3"
        case .num4: "4"
        case .num5: "5"
        case .num6: "6"
        case .num7: "7"
        case .num8: "8"
        case .num9: "9"
        case .star: "*"
        case .pound: "#"
        case .softkeyLeft: "L"
        case .softkeyRight: "R"
        }
    }

    var keyCode: String {
        switch self {
        case .up: "ArrowUp"
        case .down: "ArrowDown"
        case .left: "ArrowLeft"
        case .right: "ArrowRight"
        case .fire: "Enter"
        case .num0: "Digit0"
        case .num1: "Digit1"
        case .num2: "Digit2"
        case .num3: "Digit3"
        case .num4: "Digit4"
        case .num5: "Digit5"
        case .num6: "Digit6"
        case .num7: "Digit7"
        case .num8: "Digit8"
        case .num9: "Digit9"
        case .star: "KeyE"
        case .pound: "KeyR"
        case .softkeyLeft: "F1"
        case .softkeyRight: "F2"
        }
    }
}

struct ControllerButtonLayout: Codable, Identifiable, Hashable {
    var button: J2MEButton
    var x: Double
    var y: Double
    var scale: Double
    var opacity: Double

    var id: String { button.id }
}

struct ControllerLayout: Codable, Hashable {
    var buttons: [ControllerButtonLayout]

    static let `default` = ControllerLayout(buttons: [
        .init(button: .up, x: 0.20, y: 0.25, scale: 1, opacity: 0.82),
        .init(button: .left, x: 0.10, y: 0.43, scale: 1, opacity: 0.82),
        .init(button: .fire, x: 0.20, y: 0.43, scale: 1, opacity: 0.82),
        .init(button: .right, x: 0.30, y: 0.43, scale: 1, opacity: 0.82),
        .init(button: .down, x: 0.20, y: 0.61, scale: 1, opacity: 0.82),
        .init(button: .softkeyLeft, x: 0.10, y: 0.84, scale: 0.9, opacity: 0.82),
        .init(button: .softkeyRight, x: 0.90, y: 0.84, scale: 0.9, opacity: 0.82),
        .init(button: .num2, x: 0.76, y: 0.25, scale: 1, opacity: 0.82),
        .init(button: .num4, x: 0.66, y: 0.43, scale: 1, opacity: 0.82),
        .init(button: .num5, x: 0.76, y: 0.43, scale: 1, opacity: 0.82),
        .init(button: .num6, x: 0.86, y: 0.43, scale: 1, opacity: 0.82),
        .init(button: .num8, x: 0.76, y: 0.61, scale: 1, opacity: 0.82)
    ])
}
