import SwiftUI

@main
struct JavaPocketApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = GameLibraryStore()

    var body: some Scene {
        WindowGroup {
            GameLibraryView()
                .environmentObject(library)
                .tint(.indigo)
                .onOpenURL { library.importURLs([$0]) }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        library.reload()
                    }
                }
        }
    }
}
