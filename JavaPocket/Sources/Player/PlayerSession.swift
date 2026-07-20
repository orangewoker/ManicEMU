import Foundation

@MainActor
final class PlayerSession: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?
    @Published var isMuted = false
    @Published var isFastForwarding = false
    @Published private(set) var hasSave = false
    @Published var isModifierPresented = false
    @Published private(set) var autoContinueOutcome: Bool?

    weak var emulatorView: J2MEView?

    func attach(_ view: J2MEView) {
        emulatorView = view
        hasSave = view.hasSave
        view.onReady = { [weak self] in
            self?.isReady = true
            self?.errorMessage = nil
        }
        view.onError = { [weak self] in self?.errorMessage = $0 }
        view.onSaveAvailable = { [weak self] in self?.hasSave = true }
        view.onAutoContinueComplete = { [weak self] success in
            self?.autoContinueOutcome = success
        }
    }

    func press(_ button: J2MEButton, pressed: Bool) {
        emulatorView?.press(button, pressed: pressed)
    }

    func toggleMute() {
        isMuted.toggle()
        emulatorView?.setMuted(isMuted)
    }

    func toggleFastForward() {
        isFastForwarding.toggle()
        emulatorView?.setSpeed(isFastForwarding ? 2 : 1)
    }

    func toggleModifier() {
        guard isReady else { return }
        isModifierPresented.toggle()
    }

    func modifierFirstScan(type: ModifierValueType, value: Double) async throws -> ModifierScanPage {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        return try await emulatorView.modifierFirstScan(type: type, value: value)
    }

    func modifierRefine(filter: ModifierFilter, value: Double) async throws -> ModifierScanPage {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        return try await emulatorView.modifierRefine(filter: filter, value: value)
    }

    func modifierRefresh() async throws -> ModifierScanPage {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        return try await emulatorView.modifierRefresh()
    }

    func modifierWrite(candidate: ModifierCandidate, value: Double, freeze: Bool) async throws -> ModifierScanPage {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        return try await emulatorView.modifierWrite(candidate: candidate, value: value, freeze: freeze)
    }

    func modifierReset() async throws {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        try await emulatorView.modifierReset()
    }

    func modifierScanSave(type: ModifierValueType, value: Double) async throws -> ModifierScanPage {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        return try await emulatorView.modifierScanSave(type: type, value: value)
    }

    func modifierWriteSave(candidate: ModifierCandidate, value: Double) async throws {
        guard let emulatorView else { throw DataModifierError.runtimeUnavailable }
        try await emulatorView.modifierWriteSave(candidate: candidate, value: value)
    }

    func pause() { emulatorView?.pause() }
    func resume() { emulatorView?.resume() }
    func save(completion: ((Bool) -> Void)? = nil) {
        guard let emulatorView else {
            completion?(false)
            return
        }
        emulatorView.save { [weak self] success in
            if success { self?.hasSave = true }
            completion?(success)
        }
    }

    @discardableResult
    func loadLastSave() -> Bool {
        guard let emulatorView, emulatorView.hasSave else { return false }
        isReady = false
        errorMessage = nil
        autoContinueOutcome = nil
        let started = emulatorView.loadLastSave()
        if !started { isReady = true }
        return started
    }
}
