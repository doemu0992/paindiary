import SwiftUI

/// Anpassen der Einblicke: Bausteine je Gruppe ein-/ausblenden und umsortieren.
struct EinblickeAnpassenView: View {
    @Binding var konfig: EinblickeKonfiguration
    @Binding var kachelKonfig: [KachelKonfiguration]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active
    @State private var zeigeKorrelationen = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(EinblickeGruppe.allCases, id: \.self) { gruppe in
                    Section {
                        ForEach(konfig.alle(in: gruppe), id: \.self) { block in
                            HStack(spacing: 12) {
                                Text(block.titel).font(.subheadline)
                                Spacer()
                                Button {
                                    withAnimation { konfig.umschalten(block) }
                                } label: {
                                    Image(systemName: konfig.istSichtbar(block) ? "eye.fill" : "eye.slash")
                                        .foregroundStyle(konfig.istSichtbar(block) ? Color.primary : Color.secondary.opacity(0.5))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(konfig.istSichtbar(block) ? "\(block.titel) ausblenden" : "\(block.titel) einblenden")
                            }
                            .opacity(konfig.istSichtbar(block) ? 1 : 0.5)
                        }
                        .onMove { konfig.verschiebe(in: gruppe, von: $0, nach: $1) }
                    } header: {
                        Text(gruppe.titel)
                    }
                    .listRowBackground(GlassRowBackground())
                }

                Section {
                    Button { zeigeKorrelationen = true } label: {
                        Label("Eigene Korrelationen verwalten", systemImage: "chart.xyaxis.line")
                    }
                } footer: {
                    Text("Eigene Korrelations-Kacheln erscheinen unter „Analyse“.").font(.caption2)
                }
                .listRowBackground(GlassRowBackground())
            }
            .environment(\.editMode, $editMode)
            .glassList(.statistik)
            .navigationTitle("Einblicke anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .onChange(of: konfig) { _, neu in EinblickeKonfigurationSpeicher.speichern(neu) }
            .sheet(isPresented: $zeigeKorrelationen) {
                DashboardAnpassenView(kacheln: $kachelKonfig)
            }
            .onChange(of: kachelKonfig) { _, neu in neu.speichern() }
        }
        .presentationDetents([.large])
    }
}
