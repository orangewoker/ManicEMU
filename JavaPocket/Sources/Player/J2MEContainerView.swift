import SwiftUI

struct J2MEContainerView: UIViewRepresentable {
    let game: GameRecord
    let storage: GameStorage
    let continueGame: Bool
    let session: PlayerSession
    let onExit: () -> Void

    func makeUIView(context: Context) -> J2MEView {
        let view = J2MEView(game: game, storage: storage, shouldLoadSave: continueGame)
        view.onExit = onExit
        session.attach(view)
        return view
    }

    func updateUIView(_ uiView: J2MEView, context: Context) {}

    static func dismantleUIView(_ uiView: J2MEView, coordinator: Void) {
        uiView.save()
        uiView.pause()
    }
}
