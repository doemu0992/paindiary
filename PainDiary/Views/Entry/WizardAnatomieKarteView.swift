import SwiftUI

struct WizardAnatomieKarteView: View {
    @Binding var koerperstelle: String
    @StateObject private var scanService = BodyScanService.shared
    @State private var scanSetupAnzeigen = false
    @State private var pendingRegion: String? = nil
    @State private var drillDownAnzeigen = false

    private var ausgewaehlt: Set<String> {
        Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Wo hast du Schmerzen?")
                    .font(.title2.bold())
                Spacer()
                Button {
                    scanSetupAnzeigen = true
                } label: {
                    Label(scanService.hatScan ? "Neu scannen" : "Körper scannen",
                          systemImage: scanService.hatScan ? "arrow.triangle.2.circlepath" : "camera.viewfinder")
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            KoerperKarte3DView(
                ausgewaehlt: ausgewaehlt,
                onTap: handleTap,
                proportionen: scanService.proportionen
            )
            .frame(height: 420)

            if ausgewaehlt.isEmpty {
                Text("Tippe auf eine Körperstelle")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(height: 30)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ausgewaehlt.sorted(), id: \.self) { r in
                            Button {
                                var s = ausgewaehlt
                                s.remove(r)
                                koerperstelle = s.sorted().joined(separator: ", ")
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    Text(r).font(.caption)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 30)
            }

            Label("Drehen zum Erkunden", systemImage: "hand.draw")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
        .sheet(isPresented: $drillDownAnzeigen) {
            if let region = pendingRegion {
                SubRegionenSheet(region: region, ausgewaehlt: ausgewaehlt) { gewählt in
                    var s = ausgewaehlt
                    gewählt.forEach { s.insert($0) }
                    koerperstelle = s.sorted().joined(separator: ", ")
                }
            }
        }
    }

    private func handleTap(_ name: String) {
        if let subs = SubRegionen.map[name] {
            // Any sub-region or the region itself already selected → deselect all
            let hasSelection = ausgewaehlt.contains(name) || subs.contains { ausgewaehlt.contains($0) }
            if hasSelection {
                var s = ausgewaehlt
                s.remove(name)
                subs.forEach { s.remove($0) }
                koerperstelle = s.sorted().joined(separator: ", ")
            } else {
                pendingRegion = name
                drillDownAnzeigen = true
            }
        } else {
            var s = ausgewaehlt
            if s.contains(name) { s.remove(name) } else { s.insert(name) }
            koerperstelle = s.sorted().joined(separator: ", ")
        }
    }
}

// MARK: - Sub-region drill-down sheet

private struct SubRegionenSheet: View {
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
