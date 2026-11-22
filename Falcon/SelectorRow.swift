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
                HStack(spacing: 6) {
                    Text(client.name)
                        .font(.body.weight(.semibold))
                    if client.isCustom {
                        Text("Custom")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(client.note ?? (client.url == nil ? "Bundle missing" : "Tap to launch"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}
