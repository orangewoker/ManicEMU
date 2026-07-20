import SwiftUI

@MainActor
private final class J2MERuntimeCache {
    static let shared = J2MERuntimeCache()
    private var cached: (gameID: String, view: J2MEView)?

    func take(gameID: String) -> J2MEView? {
        guard cached?.gameID == gameID else { return nil }
        let view = cached?.view
        cached = nil
        return view
    }

    func store(_ view: J2MEView) {
        cached = (view.gameID, view)
    }

    func discard(gameID: String) {
        guard cached?.gameID == gameID else { return }
        cached = nil
    }
}

struct J2MEContainerView: UIViewRepresentable {
    let game: GameRecord
    let storage: GameStorage
    let continueGame: Bool
    let session: PlayerSession
    let onExit: () -> Void

    func makeUIView(context: Context) -> J2MEView {
        if continueGame, let cached = J2MERuntimeCache.shared.take(gameID: game.id) {
            cached.onExit = onExit
            session.attach(cached)
            cached.setMuted(false)
            cached.setSpeed(1)
            cached.resume()
            if cached.hasQuickSnapshot {
                Task { _ = await session.restoreQuickSnapshot() }
            }
            return cached
        }

        J2MERuntimeCache.shared.discard(gameID: game.id)
        let view = J2MEView(game: game, storage: storage, shouldLoadSave: continueGame)
        view.onExit = onExit
        session.attach(view)
        return view
    }

    func updateUIView(_ uiView: J2MEView, context: Context) {}

    static func dismantleUIView(_ uiView: J2MEView, coordinator: Void) {
        uiView.save()
        uiView.pause()
        J2MERuntimeCache.shared.store(uiView)
    }
}
