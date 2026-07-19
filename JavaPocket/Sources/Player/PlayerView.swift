import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var library: GameLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let gameID: String
    let continueGame: Bool

    @StateObject private var session = PlayerSession()
    @State private var isQuitConfirmationPresented = false
    @State private var layout = ControllerLayout.default

    var body: some View {
        GeometryReader { proxy in
            if let game = library.record(for: gameID) {
                let isLandscape = proxy.size.width > proxy.size.height
                ZStack {
                    Color.black.ignoresSafeArea()
                    if isLandscape {
                        landscapeLayout(game: game)
                    } else {
                        portraitLayout(game: game)
                    }
                    PlayerToolbar(
                        title: game.name,
                        isMuted: session.isMuted,
                        mute: session.toggleMute,
                        quit: { isQuitConfirmationPresented = true }
                    )
                    if !session.isReady {
                        LoadingRuntimeView(error: session.errorMessage)
                    }
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: loadLayout)
        .onChange(of: scenePhase, perform: handleScenePhase)
        .confirmationDialog("退出游戏？", isPresented: $isQuitConfirmationPresented) {
            Button("保存并退出", role: .destructive, action: saveAndDismiss)
            Button("取消", role: .cancel) {}
        }
    }

    private func portraitLayout(game: GameRecord) -> some View {
        VStack(spacing: 0) {
            emulator(game: game)
                .padding(.top, 52)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
            controller(for: game)
                .frame(height: 300)
                .background(Color(uiColor: .secondarySystemBackground))
        }
    }

    private func landscapeLayout(game: GameRecord) -> some View {
        ZStack {
            emulator(game: game)
                .padding(.horizontal, 150)
                .padding(.vertical, 12)
            controller(for: game)
                .padding(.top, 44)
        }
    }

    private func emulator(game: GameRecord) -> some View {
        J2MEContainerView(
            game: game,
            storage: library.storage,
            continueGame: continueGame,
            session: session,
            onExit: saveAndDismiss
        )
        .aspectRatio(
            CGFloat(game.screenWidth) / CGFloat(max(game.screenHeight, 1)),
            contentMode: .fit
        )
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func controller(for game: GameRecord) -> some View {
        switch game.controllerMode {
        case .nokia:
            NokiaControllerView(onButton: session.press)
        case .joystick:
            JoystickControllerView(onButton: session.press)
        case .custom:
            CustomControllerView(layout: layout, onButton: session.press)
        }
    }

    private func loadLayout() {
        layout = ControllerLayoutStore(storage: library.storage).load(gameID: gameID)
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active: session.resume()
        case .inactive: session.pause()
        case .background: session.save()
        @unknown default: break
        }
    }

    private func saveAndDismiss() {
        session.save { _ in dismiss() }
    }
}

private struct PlayerToolbar: View {
    let title: String
    let isMuted: Bool
    let mute: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Button(action: quit) {
                    Image(systemName: "xmark")
                }
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: mute) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(.black.opacity(0.72))
            Spacer()
        }
    }
}

private struct LoadingRuntimeView: View {
    let error: String?

    var body: some View {
        VStack(spacing: 14) {
            if let error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(error).multilineTextAlignment(.center)
            } else {
                ProgressView().tint(.white)
                Text("正在启动 Java ME…")
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
        .padding(30)
    }
}
