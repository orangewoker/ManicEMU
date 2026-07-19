import SwiftUI

struct ControllerButtonView: View {
    let button: J2MEButton
    var size: CGFloat = 54
    var opacity: Double = 0.82
    let onChanged: (Bool) -> Void

    @State private var isPressed = false

    var body: some View {
        Text(button.title)
            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isPressed ? Color.indigo : Color.black)
                    .opacity(opacity)
            )
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            .scaleEffect(isPressed ? 0.92 : 1)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in setPressed(true) }
                    .onEnded { _ in setPressed(false) }
            )
            .accessibilityLabel(button.rawValue)
    }

    private func setPressed(_ pressed: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        onChanged(pressed)
    }
}
