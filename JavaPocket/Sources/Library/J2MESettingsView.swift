import SwiftUI

struct J2MESettingsView: View {
    @EnvironmentObject private var library: GameLibraryStore
    @Environment(\.dismiss) private var dismiss

    let gameID: String

    @State private var rotation = false
    @State private var width = 240.0
    @State private var height = 320.0
    @State private var didLoad = false

    private let presets: [(Int, Int)] = [
        (96, 65), (96, 96), (104, 80), (128, 128), (132, 176),
        (128, 160), (176, 208), (176, 220), (208, 208), (240, 320),
        (320, 240), (240, 400), (352, 416), (360, 640), (640, 360),
        (480, 800), (800, 480)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    sectionTitle("旋转屏幕")
                    settingCard {
                        HStack(spacing: 16) {
                            settingIcon("rectangle.portrait.rotate")
                            Text("旋转屏幕")
                                .font(.title3.bold())
                            Spacer()
                            Toggle("", isOn: $rotation)
                                .labelsHidden()
                                .tint(.red)
                        }
                        .padding(18)
                    }

                    sectionTitle("屏幕尺寸")
                    settingCard {
                        VStack(spacing: 20) {
                            HStack(spacing: 16) {
                                settingIcon("rectangle.inset.filled")
                                Text("屏幕尺寸")
                                    .font(.title3.bold())
                                Spacer()
                                Text("\(Int(width))  X  \(Int(height))")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Menu {
                                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                                        Button("\(preset.0)x\(preset.1)") {
                                            width = Double(preset.0)
                                            height = Double(preset.1)
                                        }
                                    }
                                    Button("自定义") {
                                        // The width and height sliders below are always
                                        // available for custom logical resolutions.
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 18)

                            Divider().overlay(.white.opacity(0.05))

                            dimensionSlider(title: "宽度", value: $width, range: 96...800)
                            dimensionSlider(title: "高度", value: $height, range: 65...800)
                        }
                        .padding(.bottom, 20)
                    }

                    Text("由于 JAR 标准存在差异，JavaPocket 有时无法自动获取正确的分辨率或屏幕方向。为了获得更好的显示效果，您可以手动进行配置。")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }
            .background(Color(red: 0.055, green: 0.055, blue: 0.075).ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("☕︎  J2ME 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.055, green: 0.055, blue: 0.075), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.headline.bold())
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.04), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.16)))
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .interactiveDismissDisabled(false)
        .onDisappear(perform: save)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }

    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.105, green: 0.105, blue: 0.135), in: RoundedRectangle(cornerRadius: 22))
    }

    private func settingIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .frame(width: 42, height: 42)
            .background(Color(red: 1, green: 0.08, blue: 0.2), in: RoundedRectangle(cornerRadius: 9))
    }

    private func dimensionSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title).font(.headline)
                Text("\(Int(value.wrappedValue))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
                .tint(Color(red: 1, green: 0.08, blue: 0.2))
        }
        .padding(.horizontal, 18)
    }

    private func load() {
        guard !didLoad, let game = library.record(for: gameID) else { return }
        didLoad = true
        rotation = game.isScreenRotationEnabled
        width = Double(game.screenWidth)
        height = Double(game.screenHeight)
    }

    private func save() {
        guard didLoad else { return }
        library.setJ2MESettings(rotation: rotation, width: Int(width), height: Int(height), for: gameID)
    }

    private func close() {
        save()
        dismiss()
    }
}
