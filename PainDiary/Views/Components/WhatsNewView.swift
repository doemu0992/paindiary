import SwiftUI

struct WhatsNewView: View {
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var eintrag: WhatsNewVersion? { whatsNewFuerAktuelleVersion() }

    private var versionAnzeige: String {
        guard let e = eintrag else { return "" }
        return "Version \(e.version) (\(e.build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(eintrag?.aenderungen ?? []) { item in
                        aenderungZeile(item)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 120)
            }
            footer
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                Text("Was ist neu")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(versionAnzeige)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 44)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private func aenderungZeile(_ item: WhatsNewAenderung) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.farbe.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(item.farbe)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.titel)
                    .font(.headline)
                Text(item.beschreibung)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                onDismiss()
            } label: {
                Text("Weiter")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }
}
