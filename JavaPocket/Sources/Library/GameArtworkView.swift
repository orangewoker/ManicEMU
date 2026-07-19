import SwiftUI

struct GameArtworkView: View {
    let game: GameRecord
    let storage: GameStorage

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.85), Color.cyan.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(18)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 42, weight: .semibold))
                    Text("J2ME")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                }
                .foregroundStyle(.white)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if game.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .padding(10)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
    }

    private func loadImage() -> UIImage? {
        guard let url = storage.iconURL(for: game),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }
}
