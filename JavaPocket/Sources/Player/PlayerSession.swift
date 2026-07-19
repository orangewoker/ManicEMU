import Foundation

@MainActor
final class PlayerSession: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?
    @Published var isMuted = false

    weak var emulatorView: J2MEView?

    func attach(_ view: J2MEView) {
        emulatorView = view
        view.onReady = { [weak self] in self?.isReady = true }
        view.onError = { [weak self] in self?.errorMessage = $0 }
    }

    func press(_ button: J2MEButton, pressed: Bool) {
        emulatorView?.press(button, pressed: pressed)
    }

    func toggleMute() {
        isMuted.toggle()
        emulatorView?.setMuted(isMuted)
    }

    func pause() { emulatorView?.pause() }
    func resume() { emulatorView?.resume() }
    func save(completion: ((Bool) -> Void)? = nil) { emulatorView?.save(completion: completion) }
}
