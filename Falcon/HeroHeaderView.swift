import SwiftUI

/// Modern, console-style featured hero card displaying the focused game.
/// Styled like Apple Arcade / Steam Deck featured banner with a clean vignette,
/// typography, and an unmistakable "Play Now" action button.
/// Adapts gracefully between Portrait and Landscape orientations, and supports direct controller focus.
struct HeroHeaderView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let client: GameClient
    let coverImage: Image
    var isFocused: Bool = false
    let onPlay: () -> Void

    private var heroHeight: CGFloat {
        verticalSizeClass == .compact ? 175 : 220
    }

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
            VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? 6 : 10) {
                // Top Tag
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(client.isCustom ? "CUSTOM CLIENT" : "FEATURED")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )

                Spacer()

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(verticalSizeClass == .compact ? .title3.weight(.bold) : .title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 4, y: 2)

                    if let note = client.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(verticalSizeClass == .compact ? 1 : 2)
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
                    .padding(.horizontal, isFocused ? 22 : 18)
                    .padding(.vertical, verticalSizeClass == .compact ? (isFocused ? 9 : 7) : (isFocused ? 11 : 9))
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(
                        color: isFocused ? Color.white.opacity(0.9) : Color.black.opacity(0.4),
                        radius: isFocused ? 10 : 6,
                        y: 3
                    )
                    .scaleEffect(isFocused ? 1.05 : 1.0)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 2)
            }
            .padding(verticalSizeClass == .compact ? 14 : 18)
        }
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.white : Color.white.opacity(0.12),
                    lineWidth: isFocused ? 3 : 1
                )
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .shadow(
            color: isFocused ? Color.white.opacity(0.35) : Color.black.opacity(0.6),
            radius: isFocused ? 16 : 12,
            y: 6
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
    }
}
