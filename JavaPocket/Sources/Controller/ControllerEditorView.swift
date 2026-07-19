import SwiftUI

struct ControllerEditorView: View {
    @EnvironmentObject private var library: GameLibraryStore
    @Environment(\.dismiss) private var dismiss
    let game: GameRecord

    @State private var mode: ControllerMode
    @State private var layout: ControllerLayout
    @State private var selectedButton: J2MEButton?

    init(game: GameRecord) {
        self.game = game
        _mode = State(initialValue: game.controllerMode)
        _layout = State(initialValue: .default)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("控制器", selection: $mode) {
                    ForEach(ControllerMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .custom {
                    customEditor
                    if let index = selectedIndex {
                        VStack {
                            HStack {
                                Text("大小")
                                Slider(value: $layout.buttons[index].scale, in: 0.6...1.8)
                            }
                            HStack {
                                Text("透明度")
                                Slider(value: $layout.buttons[index].opacity, in: 0.25...1)
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                } else {
                    ControllerPreview(mode: mode)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("设置按键")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
            .task { loadLayout() }
        }
    }

    private var customEditor: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.06))
                ForEach(Array(layout.buttons.enumerated()), id: \.element.id) { index, item in
                    ControllerButtonView(
                        button: item.button,
                        size: 54 * item.scale,
                        opacity: item.opacity,
                        onChanged: { _ in selectedButton = item.button }
                    )
                    .overlay {
                        if selectedButton == item.button {
                            Circle().stroke(Color.indigo, lineWidth: 3)
                        }
                    }
                    .position(
                        x: proxy.size.width * item.x,
                        y: proxy.size.height * item.y
                    )
                    .highPriorityGesture(
                        DragGesture()
                            .onChanged { value in
                                selectedButton = item.button
                                layout.buttons[index].x = min(max(value.location.x / proxy.size.width, 0.04), 0.96)
                                layout.buttons[index].y = min(max(value.location.y / proxy.size.height, 0.06), 0.94)
                            }
                    )
                }
            }
        }
        .frame(minHeight: 360)
    }

    private var selectedIndex: Int? {
        guard let selectedButton else { return nil }
        return layout.buttons.firstIndex { $0.button == selectedButton }
    }

    private func loadLayout() {
        layout = ControllerLayoutStore(storage: library.storage).load(gameID: game.id)
    }

    private func save() {
        library.setControllerMode(mode, for: game)
        try? ControllerLayoutStore(storage: library.storage).save(layout, gameID: game.id)
        dismiss()
    }
}

private struct ControllerPreview: View {
    let mode: ControllerMode

    var body: some View {
        Group {
            if mode == .nokia {
                NokiaControllerView { _, _ in }
            } else {
                JoystickControllerView { _, _ in }
            }
        }
        .padding()
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }
}
