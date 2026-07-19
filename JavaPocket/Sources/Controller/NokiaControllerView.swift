import SwiftUI

struct NokiaControllerView: View {
    let onButton: (J2MEButton, Bool) -> Void

    private let keypad: [[J2MEButton]] = [
        [.num1, .num2, .num3],
        [.num4, .num5, .num6],
        [.num7, .num8, .num9],
        [.star, .num0, .pound]
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 10) {
                HStack {
                    key(.softkeyLeft, size: 48)
                    Spacer()
                    key(.softkeyRight, size: 48)
                }
                dPad
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                ForEach(keypad.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(keypad[row]) { button in key(button, size: 46) }
                    }
                }
            }
        }
        .padding(14)
    }

    private var dPad: some View {
        VStack(spacing: 1) {
            key(.up)
            HStack(spacing: 1) {
                key(.left)
                key(.fire)
                key(.right)
            }
            key(.down)
        }
    }

    private func key(_ button: J2MEButton, size: CGFloat = 52) -> some View {
        ControllerButtonView(button: button, size: size) { onButton(button, $0) }
    }
}
