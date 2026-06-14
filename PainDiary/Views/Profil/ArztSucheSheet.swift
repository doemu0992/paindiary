import SwiftUI
import MapKit

struct ArztSucheSheet: View {
    let onAuswahl: (String, String, String, String) -> Void // praxis, adresse, telefon, name
    @Environment(\.dismiss) private var dismiss
    @State private var suchtext = ""
    @State private var ergebnisse: [MKMapItem] = []
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
                    ForEach(ergebnisse, id: \.self) { item in
                        Button {
                            waehle(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let adresse = formatAdresse(item.placemark) {
                                    Text(adresse)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let tel = item.phoneNumber, !tel.isEmpty {
                                    Label(tel, systemImage: "phone")
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
            sucht = false
            let items = resp?.mapItems ?? []
            ergebnisse = items
            keineErgebnisse = items.isEmpty
        }
    }

    private func waehle(_ item: MKMapItem) {
        let praxis = item.name ?? ""
        let adresse = formatAdresse(item.placemark) ?? ""
        let telefon = item.phoneNumber ?? ""
        onAuswahl(praxis, adresse, telefon, "")
        dismiss()
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
