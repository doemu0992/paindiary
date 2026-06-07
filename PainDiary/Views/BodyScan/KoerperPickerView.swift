import SwiftUI

// MARK: - Reusable body-region picker with drill-down sub-region support

struct KoerperPickerView: View {
    @Binding var auswahl: String
    var tintColor: UIColor = .systemRed
    var frameHeight: CGFloat = 420

    @StateObject private var scanService = BodyScanService.shared
    @State private var pendingRegion: RegionItem? = nil

    private var ausgewaehltSet: Set<String> {
        Set(auswahl.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        KoerperKarte3DView(
            ausgewaehlt: ausgewaehltSet,
            onTap: handleTap,
            proportionen: scanService.proportionen,
            tintColor: tintColor
        )
        .frame(height: frameHeight)
        .sheet(item: $pendingRegion) { item in
            SubRegionenSheet(region: item.id, ausgewaehlt: ausgewaehltSet) { gewählt in
                var s = ausgewaehltSet
                gewählt.forEach { s.insert($0) }
                auswahl = s.sorted().joined(separator: ", ")
            }
        }
    }

    private func handleTap(_ name: String) {
        if let subs = SubRegionen.map[name] {
            let hasSelection = ausgewaehltSet.contains(name) || subs.contains { ausgewaehltSet.contains($0) }
            if hasSelection {
                var s = ausgewaehltSet
                s.remove(name)
                subs.forEach { s.remove($0) }
                auswahl = s.sorted().joined(separator: ", ")
            } else {
                pendingRegion = RegionItem(id: name)
            }
        } else {
            var s = ausgewaehltSet
            if s.contains(name) { s.remove(name) } else { s.insert(name) }
            auswahl = s.sorted().joined(separator: ", ")
        }
    }
}

// MARK: - Identifiable wrapper for sheet(item:)

struct RegionItem: Identifiable {
    let id: String
}

// MARK: - Sub-region drill-down sheet

struct SubRegionenSheet: View {
    let region: String
    let ausgewaehlt: Set<String>
    let onConfirm: (Set<String>) -> Void

    @State private var lokalAusgewaehlt: Set<String> = []
    @State private var freitext = ""
    @Environment(\.dismiss) private var dismiss

    private var subs: [String] { SubRegionen.map[region] ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Wo genau bei \"\(region)\"?")
                        .font(.headline)
                        .padding(.top, 4)

                    FlowLayout(subs) { sub in
                        ChipButton(label: sub, ausgewaehlt: lokalAusgewaehlt.contains(sub)) {
                            if lokalAusgewaehlt.contains(sub) { lokalAusgewaehlt.remove(sub) }
                            else { lokalAusgewaehlt.insert(sub) }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Andere Stelle…", text: $freitext)
                            .textFieldStyle(.roundedBorder)
                        if !freitext.isEmpty {
                            Button {
                                lokalAusgewaehlt.insert(freitext.trimmingCharacters(in: .whitespaces))
                                freitext = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.title2)
                            }
                        }
                    }

                    Divider()

                    Button {
                        onConfirm([region])
                        dismiss()
                    } label: {
                        Text("Nur \"\(region)\" ohne Präzisierung")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle(region)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        var result = lokalAusgewaehlt
                        let t = freitext.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { result.insert(t) }
                        onConfirm(result.isEmpty ? [region] : result)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            lokalAusgewaehlt = ausgewaehlt.intersection(Set(subs))
        }
    }
}
