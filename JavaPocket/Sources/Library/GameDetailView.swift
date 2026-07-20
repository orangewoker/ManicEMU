import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject private var library: GameLibraryStore
    @Environment(\.dismiss) private var dismiss
    let gameID: String

    @State private var destination: PlayerDestination?
    @State private var isDeleteConfirmationPresented = false
    @State private var isJ2MESettingsPresented = false

    var body: some View {
        ScrollView {
            if let game = library.record(for: gameID) {
                VStack(spacing: 24) {
                    GameArtworkView(game: game, storage: library.storage)
                        .frame(maxWidth: 260)
                    GameTitleSection(game: game)
                    GameMetadataSection(game: game)
                    GameActionsSection(
                        canContinue: library.storage.hasSave(for: game.id),
                        start: { start(game, continueGame: false) },
                        continueGame: { start(game, continueGame: true) },
                        editResolution: { isJ2MESettingsPresented = true },
                        delete: { isDeleteConfirmationPresented = true }
                    )
                }
                .padding(20)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("游戏详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let game = library.record(for: gameID) {
                Button {
                    library.toggleFavorite(game)
                } label: {
                    Image(systemName: game.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(game.isFavorite ? "取消收藏" : "收藏")
            }
        }
        .fullScreenCover(item: $destination) { destination in
            PlayerView(gameID: destination.gameID, continueGame: destination.continueGame)
        }
        .sheet(isPresented: $isJ2MESettingsPresented) {
            J2MESettingsView(gameID: gameID)
                .presentationDetents([.large])
        }
        .confirmationDialog("删除这个游戏及其存档？", isPresented: $isDeleteConfirmationPresented) {
            Button("删除游戏", role: .destructive, action: deleteGame)
        }
    }

    private func start(_ game: GameRecord, continueGame: Bool) {
        library.markPlayed(game)
        destination = PlayerDestination(gameID: game.id, continueGame: continueGame)
    }

    private func deleteGame() {
        guard let game = library.record(for: gameID) else { return }
        library.delete(game)
        dismiss()
    }
}

private struct PlayerDestination: Identifiable {
    let gameID: String
    let continueGame: Bool
    var id: String { "\(gameID)-\(continueGame)" }
}

private struct GameTitleSection: View {
    let game: GameRecord

    var body: some View {
        VStack(spacing: 7) {
            Text(game.name)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(game.vendor)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("版本 \(game.version)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct GameMetadataSection: View {
    let game: GameRecord

    var body: some View {
        VStack(spacing: 0) {
            MetadataRow(icon: "shippingbox", title: "MIDlet", value: game.mainClass ?? game.name)
            Divider().padding(.leading, 48)
            MetadataRow(icon: "cup.and.saucer", title: "Java", value: game.javaVersion)
            Divider().padding(.leading, 48)
            MetadataRow(icon: "rectangle", title: "屏幕", value: game.resolution)
            Divider().padding(.leading, 48)
            MetadataRow(icon: "building.2", title: "厂商", value: game.vendor)
            Divider().padding(.leading, 48)
            MetadataRow(icon: "gamecontroller", title: "按键", value: "ManicEMU 经典键盘")
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MetadataRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.indigo)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(15)
    }
}

private struct GameActionsSection: View {
    let canContinue: Bool
    let start: () -> Void
    let continueGame: () -> Void
    let editResolution: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: start) {
                Label("开始游戏", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: continueGame) {
                Label("继续游戏", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!canContinue)

            Button(action: editResolution) {
                Label("分辨率设置", systemImage: "aspectratio")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(role: .destructive, action: delete) {
                Label("删除游戏", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
