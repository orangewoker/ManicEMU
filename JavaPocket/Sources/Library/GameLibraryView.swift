import SwiftUI
import UniformTypeIdentifiers

struct GameLibraryView: View {
    @EnvironmentObject private var library: GameLibraryStore
    @State private var isImporterPresented = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 190), spacing: 18)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LibraryHero()
                    Picker("筛选", selection: $library.filter) {
                        ForEach(GameLibraryStore.Filter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if library.visibleGames.isEmpty {
                        EmptyLibraryView(importAction: presentImporter)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 54)
                    } else if library.isGrid {
                        LazyVGrid(columns: gridColumns, spacing: 24) {
                            ForEach(library.visibleGames) { game in
                                NavigationLink(value: game.id) {
                                    GameGridCard(game: game)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { contextMenu(for: game) }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(library.visibleGames) { game in
                                NavigationLink(value: game.id) {
                                    GameListRow(game: game)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { contextMenu(for: game) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("J2ME Games")
            .searchable(text: $library.searchText, prompt: "搜索游戏或厂商")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: toggleLayout) {
                        Image(systemName: library.isGrid ? "list.bullet" : "square.grid.2x2")
                    }
                    .accessibilityLabel(library.isGrid ? "列表模式" : "网格模式")

                    Button(action: presentImporter) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("导入 JAR")
                }
            }
            .navigationDestination(for: String.self) { gameID in
                if let game = library.record(for: gameID) {
                    GameDetailView(gameID: game.id)
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                // Files may report a JAR as public.data, public.zip-archive, or
                // com.sun.java-archive. Filtering by our exported UTI disables
                // otherwise valid JARs, so validate the extension after picking.
                allowedContentTypes: [.data],
                allowsMultipleSelection: true,
                onCompletion: handleImport
            )
            .overlay {
                if library.isImporting {
                    ImportProgressView()
                }
            }
            .alert(importAlertTitle, isPresented: importFeedbackBinding) {
                Button("好", role: .cancel) {
                    library.importError = nil
                    library.importNotice = nil
                }
            } message: {
                Text(library.importError ?? library.importNotice ?? "")
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for game: GameRecord) -> some View {
        Button {
            library.toggleFavorite(game)
        } label: {
            Label(game.isFavorite ? "取消收藏" : "收藏", systemImage: game.isFavorite ? "heart.slash" : "heart")
        }
        Button(role: .destructive) {
            library.delete(game)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var importFeedbackBinding: Binding<Bool> {
        Binding(
            get: { library.importError != nil || library.importNotice != nil },
            set: {
                if !$0 {
                    library.importError = nil
                    library.importNotice = nil
                }
            }
        )
    }

    private var importAlertTitle: String {
        library.importError == nil ? "导入完成" : "导入失败"
    }

    private func presentImporter() { isImporterPresented = true }
    private func toggleLayout() { library.isGrid.toggle() }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let jars = urls.filter { $0.pathExtension.caseInsensitiveCompare("jar") == .orderedSame }
            if jars.isEmpty {
                library.importError = "请选择扩展名为 .jar 的 Java ME 游戏文件。"
            } else {
                library.importURLs(jars)
            }
        case .failure(let error): library.importError = error.localizedDescription
        }
    }
}

private struct LibraryHero: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.indigo.gradient)
                Image(systemName: "iphone.gen1.radiowaves.left.and.right")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 4) {
                Text("JavaPocket")
                    .font(.title2.bold())
                Text("把经典 Java 手机游戏装进口袋")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct EmptyLibraryView: View {
    let importAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("还没有 J2ME 游戏")
                .font(.title2.bold())
            Text("从 Files、分享菜单或 AirDrop 导入 .jar")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("导入 JAR", action: importAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct ImportProgressView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            ProgressView("正在导入 JAR…")
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct GameGridCard: View {
    @EnvironmentObject private var library: GameLibraryStore
    let game: GameRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameArtworkView(game: game, storage: library.storage)
            Text(game.name)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Text(game.vendor)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(game.resolution)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct GameListRow: View {
    @EnvironmentObject private var library: GameLibraryStore
    let game: GameRecord

    var body: some View {
        HStack(spacing: 14) {
            GameArtworkView(game: game, storage: library.storage)
                .frame(width: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(game.name).font(.headline)
                Text(game.vendor).font(.subheadline).foregroundStyle(.secondary)
                Label(game.resolution, systemImage: "rectangle.on.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if game.isFavorite {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension UTType {
    static let javaArchive = UTType(
        exportedAs: "com.javapocket.j2me-archive",
        conformingTo: .zip
    )
}
