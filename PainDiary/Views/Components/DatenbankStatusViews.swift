import SwiftUI

/// Dauerhafter Hinweis, wenn die App ohne Persistenz läuft.
struct StoreStatusBanner: View {
    let status: StoreStatus
    var hilfe: () -> Void

    var body: some View {
        if status.istNotfall {
            Button(action: hilfe) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daten werden nicht gespeichert")
                            .font(.subheadline.bold()).foregroundStyle(.primary)
                        Text("Tippe für Hilfe — deine bisherigen Daten sind nicht gelöscht.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .glassCard(radius: 18, tint: .orange, padding: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .accessibilityLabel("Warnung: Daten werden nicht gespeichert. Tippe für Hilfe.")
        }
    }
}

/// Erklärt den Notfall-Modus und bietet sichere Schritte an. Löscht nichts.
struct DatenbankHilfeSheet: View {
    let status: StoreStatus
    var erneutVersuchen: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var grund: String {
        switch status {
        case .notfall(let g), .unbrauchbar(let g): return g
        default: return ""
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 44)).foregroundStyle(.orange)
                    Text("Die Datenbank konnte nicht geöffnet werden")
                        .font(.title3.bold()).multilineTextAlignment(.center)
                    Text("Deine gespeicherten Daten wurden **nicht gelöscht**. Neue Einträge gehen verloren, sobald du die App beendest. Häufige Ursache: zu wenig freier Speicherplatz.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gib Speicherplatz frei (Einstellungen → Allgemein → iPhone-Speicher).", systemImage: "1.circle.fill")
                        Label("Tippe auf „Erneut versuchen“.", systemImage: "2.circle.fill")
                        Label("Sichere die Datenbank-Dateien, bevor du etwas anderes tust.", systemImage: "3.circle.fill")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: 20, padding: 16)

                    Button {
                        erneutVersuchen()
                        dismiss()
                    } label: { Label("Erneut versuchen", systemImage: "arrow.clockwise") }
                        .buttonStyle(.glassPrimary(tint: .accentColor, hoehe: 60))

                    let dateien = PersistenceController.vorhandeneStoreDateien
                    if !dateien.isEmpty {
                        ShareLink(items: dateien) {
                            Label("Datenbank-Dateien sichern", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.glassSecondary)
                    }

                    if !grund.isEmpty {
                        Text(grund).font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .auroraScreen()
            .navigationTitle("Datenbank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Schließen") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

/// Vollbild, wenn gar kein Container erstellt werden kann.
struct DatenbankFehlerView: View {
    let status: StoreStatus
    var erneutVersuchen: () -> Void

    var body: some View {
        DatenbankHilfeSheet(status: status, erneutVersuchen: erneutVersuchen)
    }
}
