import SwiftUI

struct CustomControllerView: View {
    let layout: ControllerLayout
    let onButton: (J2MEButton, Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(layout.buttons) { item in
                    ControllerButtonView(
                        button: item.button,
                        size: 54 * item.scale,
                        opacity: item.opacity
                    ) { onButton(item.button, $0) }
                    .position(
                        x: proxy.size.width * item.x,
                        y: proxy.size.height * item.y
                    )
                }
            }
        }
    }
}
