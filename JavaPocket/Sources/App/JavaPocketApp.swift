import SwiftUI

@main
struct JavaPocketApp: App {
    @StateObject private var library = GameLibraryStore()

    var body: some Scene {
        WindowGroup {
            GameLibraryView()
                .environmentObject(library)
                .tint(.indigo)
                .onOpenURL { library.importURLs([$0]) }
        }
    }
}
