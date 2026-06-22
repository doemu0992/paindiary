import SwiftUI
import SwiftData

struct RemissionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Remissionsphase.beginn, order: .reverse) private var phasen: [Remissionsphase]

    @State private var zeigeForm = false

    private var aktivePhase: Remissionsphase? { phasen.first(where: \.istAktiv) }
    private var abgeschlossene: [Remissionsphase] { phasen.filter { !$0.istAktiv } }

    var body: some View {
        List {
            if let aktiv = aktivePhase {
                Section("Aktuelle Remission") {
                    aktiveKarte(aktiv)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if phasen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Remissionsphasen",
                        systemImage: "checkmark.seal",
                        description: Text("Tippe auf + um eine Remissionsphase zu beginnen. Eine Remission ist eine Phase ohne oder mit sehr geringer Krankheitsaktivität.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                if aktivePhase != nil {
                    Section {
                        Button(role: .destructive) {
                            beenden()
                        } label: {
                            Label("Aktive Remission beenden", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if !abgeschlossene.isEmpty {
                    Section("Abgeschlossene Phasen") {
                        ForEach(abgeschlossene) { p in
                            RemissionsZeile(phase: p)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(p)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Remissionsphasen")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
                    .disabled(aktivePhase != nil)
            }
        }
        .sheet(isPresented: $zeigeForm) { RemissionsFormView() }
    }

    @ViewBuilder
    private func aktiveKarte(_ p: Remissionsphase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Remission läuft", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                Spacer()
                // Laufend aktualisierte Anzeige ohne Timer-Boilerplate
                Text(p.beginn, style: .relative)
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beginn").font(.caption).foregroundStyle(.secondary)
                    Text(p.beginn, style: .date).font(.subheadline.bold())
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bisherige Dauer").font(.caption).foregroundStyle(.secondary)
                    Text(p.dauerText).font(.subheadline.bold()).foregroundStyle(.green)
                }
            }
            if !p.notizen.isEmpty {
                Text(p.notizen).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func beenden() {
        aktivePhase?.ende = Date()
    }
}

private struct RemissionsZeile: View {
    let phase: Remissionsphase

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phase.beginn, style: .date).font(.subheadline.bold())
                Image(systemName: "arrow.right")
                    .font(.caption).foregroundStyle(.secondary)
                if let ende = phase.ende {
                    Text(ende, style: .date).font(.subheadline.bold())
                }
                Spacer()
                Text(phase.dauerText)
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.green.opacity(0.1), in: Capsule())
            }
            if !phase.notizen.isEmpty {
                Text(phase.notizen).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct RemissionsFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var beginn  = Date()
    @State private var notizen = ""

    @State private var schritt = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                schritt0
                    .frame(maxHeight: .infinity)
                speichernLeiste
            }
            .navigationTitle("Neue Remissionsphase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "checkmark.seal.fill", titel: "Remissionsphase", untertitel: "Startdatum und optionale Notizen")

                VStack(spacing: 0) {
                    HStack {
                        Text("Startdatum").foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: $beginn, displayedComponents: [.date]).labelsHidden()
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Optionale Anmerkungen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6).font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                    Text("Eine Remission wird als aktiv markiert bis du sie manuell beendest.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var speichernLeiste: some View {
        Button { speichern() } label: {
            Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding()
        .background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.teal)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    private func speichern() {
        let neu = Remissionsphase(beginn: beginn)
        neu.notizen = notizen
        modelContext.insert(neu)
        dismiss()
    }
}
