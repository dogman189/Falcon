import SwiftUI

/// Tactile press animation button style that does not interfere with gesture recognizers or ScrollView scrolling.
struct ScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A widescreen (16:10) cover card for game clients.
///
/// Matches the natural aspect ratio of game screenshots and landscape box art.
struct GameCard: View {
    let client: GameClient
    let cover: Image
    let isFocused: Bool
    let action: () -> Void

    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 125

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Cover Image
                cover
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()

                // Bottom gradient for readable text
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Title & Details
                VStack(alignment: .leading, spacing: 2) {
                    if client.isCustom {
                        Text("CUSTOM")
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Text(client.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                }
                .padding(10)

                // Quick Play Indicator
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(isFocused ? 0.95 : 0.6))
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.white : Color.white.opacity(0.12),
                        lineWidth: isFocused ? 3 : 1
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? Color.white.opacity(0.35) : Color.black.opacity(0.4),
                radius: isFocused ? 12 : 5,
                y: isFocused ? 5 : 3
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Dashed placeholder card to import custom clients.
struct AddClientCard: View {
    var isFocused: Bool = false
    let action: () -> Void

    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 125

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.5))

                Text("Import Client")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.7))

                Text(".html / .htm")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(isFocused ? 0.7 : 0.35))
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(isFocused ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.white : Color.white.opacity(0.2),
                        style: isFocused ? StrokeStyle(lineWidth: 3) : StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? Color.white.opacity(0.3) : Color.clear,
                radius: 10,
                y: 4
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
