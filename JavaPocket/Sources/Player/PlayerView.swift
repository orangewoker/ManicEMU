import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var library: GameLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let gameID: String
    let continueGame: Bool

    @StateObject private var session = PlayerSession()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let game = library.record(for: gameID) {
                ManicJ2MESkinView(
                    game: game,
                    storage: library.storage,
                    continueGame: continueGame,
                    session: session,
                    onExit: saveAndDismiss
                )

                if !session.isReady {
                    LoadingRuntimeView(error: session.errorMessage)
                }
            }
        }
        .onChange(of: scenePhase, perform: handleScenePhase)
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
