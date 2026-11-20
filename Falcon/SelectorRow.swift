import SwiftUI

struct SelectorRow: View {
    let client: GameClient
    let cover: Image

    var body: some View {
        HStack(spacing: 12) {
            cover
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(client.name)
                        .font(.body.weight(.semibold))
                    if client.isCustom {
                        Text("CUSTOM")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                    }
                }
                Text(client.note ?? (client.url == nil ? "Bundle missing" : "Tap to launch"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}
