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
        ergebnisse = []

        Task {
            // Start all background queries immediately
            async let mk2 = mapKitSuche(query + " Arzt")
            async let mk3 = mapKitSuche(query + " Praxis")
            async let op  = overpassSuche(query)

            // Show first MapKit results as fast as possible
            let erste = await mapKitSuche(query)
            ergebnisse = erste
            if !erste.isEmpty { sucht = false }

            // Collect MapKit extras (likely already done)
            let r2 = await mk2
            let r3 = await mk3
            let aktuell = dedupliziere(erste + r2 + r3)
            ergebnisse = aktuell
            sucht = false
            keineErgebnisse = aktuell.isEmpty

            // OSM results trickle in silently — user already sees MapKit results
            let r4 = await op
            if !r4.isEmpty {
                let mitOSM = dedupliziere(aktuell + r4)
                ergebnisse = mitOSM
                keineErgebnisse = mitOSM.isEmpty
            }
        }
    }

    // MARK: - MapKit

    private func mapKitSuche(_ query: String) async -> [ArztErgebnis] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: req)
        return await withCheckedContinuation { cont in
            search.start { resp, _ in
                let items = (resp?.mapItems ?? []).compactMap { item -> ArztErgebnis? in
                    guard let name = item.name, !name.isEmpty else { return nil }
                    let adresse = formatAdresse(item.placemark) ?? ""
                    let telefon = item.phoneNumber ?? ""
                    return ArztErgebnis(praxis: name, adresse: adresse, telefon: telefon)
                }
                cont.resume(returning: items)
            }
        }
    }

    // MARK: - OpenStreetMap / Overpass

    private func overpassSuche(_ query: String) async -> [ArztErgebnis] {
        // Escape regex metacharacters for Overpass QL
        let escaped = NSRegularExpression.escapedPattern(for: query)
        // Nodes only (ways are large/slow), max 50 results, DACH bounding box
        let ql = """
        [out:json][timeout:15];
        (
          node["name"~"\(escaped)",i]["healthcare"](45.8,5.9,55.1,17.2);
          node["name"~"\(escaped)",i]["amenity"~"doctors|clinic|hospital|dentist"](45.8,5.9,55.1,17.2);
        );
        out 50;
        """
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { return [] }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        let encoded = ql.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        req.httpBody = "data=\(encoded)".data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return [] }
        return parseOverpass(data)
    }

    private func parseOverpass(_ data: Data) -> [ArztErgebnis] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]] else { return [] }
        return elements.compactMap { el -> ArztErgebnis? in
            guard let tags = el["tags"] as? [String: String],
                  let name = tags["name"], !name.isEmpty else { return nil }
            let street = [tags["addr:street"], tags["addr:housenumber"]]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let ort = [tags["addr:postcode"], tags["addr:city"]]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let adresse = [street, ort].filter { !$0.isEmpty }.joined(separator: ", ")
            let telefon = tags["phone"] ?? tags["contact:phone"] ?? ""
            return ArztErgebnis(praxis: name, adresse: adresse, telefon: telefon)
        }
    }

    // MARK: - Helpers

    private func dedupliziere(_ items: [ArztErgebnis]) -> [ArztErgebnis] {
        var seen: Set<String> = []
        return items.filter { item in
            let key = item.praxis.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined()
            return seen.insert(key).inserted
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
