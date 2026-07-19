import SwiftUI

struct JoystickControllerView: View {
    let onButton: (J2MEButton, Bool) -> Void

    var body: some View {
        HStack {
            VStack(spacing: 2) {
                button(.up)
                HStack(spacing: 2) {
                    button(.left)
                    button(.fire)
                    button(.right)
                }
                button(.down)
            }
            Spacer()
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    ControllerButtonView(button: .softkeyLeft, size: 58) { onButton(.softkeyLeft, $0) }
                    ControllerButtonView(button: .softkeyRight, size: 58) { onButton(.softkeyRight, $0) }
                }
                ControllerButtonView(button: .num5, size: 78) { onButton(.num5, $0) }
            }
        }
        .padding(22)
    }

    private func button(_ value: J2MEButton) -> some View {
        ControllerButtonView(button: value, size: 58) { onButton(value, $0) }
    }
}
