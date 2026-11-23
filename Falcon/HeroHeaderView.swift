import SwiftUI

/// Modern, console-style featured hero card displaying the focused game.
/// Styled like Apple Arcade / Steam Deck featured banner with a clean vignette,
/// typography, and an unmistakable "Play Now" action button.
struct HeroHeaderView: View {
    let client: GameClient
    let coverImage: Image
    let onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Artwork
            GeometryReader { geo in
                coverImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            // Cinematic gradient vignette
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0.0),
                    .init(color: .black.opacity(0.4), location: 0.45),
                    .init(color: .black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Left edge fade for enhanced text contrast
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.65), location: 0.0),
                    .init(color: .clear, location: 0.7)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Content Overlay
            VStack(alignment: .leading, spacing: 10) {
                // Top Tag
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(client.isCustom ? "CUSTOM CLIENT" : "FEATURED")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )

                Spacer()

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(client.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 4, y: 2)

                    if let note = client.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                    }
                }

                // Play Button
                Button(action: onPlay) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.bold))
                        Text("Play Now")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 2)
            }
            .padding(18)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
    }
}
