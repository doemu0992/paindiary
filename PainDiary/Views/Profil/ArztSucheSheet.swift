import SwiftUI
import MapKit

private struct ArztErgebnis: Identifiable {
    let id = UUID()
    let praxis: String
    let adresse: String
    let telefon: String
}

struct ArztSucheSheet: View {
    let onAuswahl: (String, String, String, String) -> Void // praxis, adresse, telefon, name
    @Environment(\.dismiss) private var dismiss
    @State private var suchtext = ""
    @State private var ergebnisse: [ArztErgebnis] = []
    @State private var sucht = false
    @State private var keineErgebnisse = false

    var body: some View {
        NavigationStack {
            List {
                if sucht {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if ergebnisse.isEmpty && keineErgebnisse {
                    ContentUnavailableView(
                        "Keine Ergebnisse",
                        systemImage: "magnifyingglass",
                        description: Text("Versuche es mit einem anderen Suchbegriff.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(ergebnisse) { item in
                        Button {
                            onAuswahl(item.praxis, item.adresse, item.telefon, "")
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.praxis)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if !item.adresse.isEmpty {
                                    Text(item.adresse)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !item.telefon.isEmpty {
                                    Label(item.telefon, systemImage: "phone")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $suchtext, placement: .navigationBarDrawer(displayMode: .always), prompt: "Arztname, Praxis, Fachgebiet…")
            .onSubmit(of: .search) { suchen() }
            .onChange(of: suchtext) { _, neu in
                if neu.isEmpty { ergebnisse = []; keineErgebnisse = false }
            }
            .navigationTitle("Arzt suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .overlay {
                if ergebnisse.isEmpty && !sucht && !keineErgebnisse {
                    VStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Arzt, Praxis oder Fachgebiet eingeben")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
    }

    private func suchen() {
        let query = suchtext.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        sucht = true
        keineErgebnisse = false
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        MKLocalSearch(request: req).start { resp, _ in
            // Extract all fields immediately so tap is instant (avoids lazy phoneNumber fetch on main thread)
            let items = (resp?.mapItems ?? []).compactMap { item -> ArztErgebnis? in
                guard let name = item.name, !name.isEmpty else { return nil }
                let adresse = formatAdresse(item.placemark) ?? ""
                let telefon = item.phoneNumber ?? ""
                return ArztErgebnis(praxis: name, adresse: adresse, telefon: telefon)
            }
            sucht = false
            ergebnisse = items
            keineErgebnisse = items.isEmpty
        }
    }

    private func formatAdresse(_ placemark: CLPlacemark) -> String? {
        let strasse = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        let ort = [placemark.postalCode, placemark.locality]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        let teile = [strasse, ort].filter { !$0.isEmpty }
        return teile.isEmpty ? nil : teile.joined(separator: ", ")
    }
}
