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

    var body: some View {
        NavigationStack {
            Form {
                Section("Remission beginnen") {
                    DatePicker("Startdatum", selection: $beginn, displayedComponents: [.date])
                }

                Section("Notizen") {
                    TextField("Optionale Anmerkungen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Label("Eine Remission wird als aktiv markiert bis du sie manuell beendest.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Neue Remissionsphase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Beginnen") { speichern() } }
            }
        }
    }

    private func speichern() {
        let neu = Remissionsphase(beginn: beginn)
        neu.notizen = notizen
        modelContext.insert(neu)
        dismiss()
    }
}
