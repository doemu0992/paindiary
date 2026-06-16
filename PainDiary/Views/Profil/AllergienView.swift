import SwiftUI
import SwiftData

struct AllergienView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Allergie.schwere) private var allergien: [Allergie]

    @State private var zeigeForm = false
    @State private var bearbeitet: Allergie? = nil

    var body: some View {
        List {
            if allergien.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Allergien",
                        systemImage: "allergens",
                        description: Text("Tippe auf + um eine Allergie einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(allergien) { a in
                    AllergieZeile(allergie: a)
                        .contentShape(Rectangle())
                        .onTapGesture { bearbeitet = a }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(a)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            .tint(.red)
                            Button { bearbeitet = a } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete { indexSet in
                    for i in indexSet { modelContext.delete(allergien[i]) }
                }
            }
        }
        .navigationTitle("Allergien & Unverträglichkeiten")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { AllergieForm() }
        .sheet(item: $bearbeitet) { AllergieForm(allergie: $0) }
    }
}

private struct AllergieZeile: View {
    let allergie: Allergie

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: allergieSymbol)
                .font(.title3)
                .foregroundStyle(allergieFarbe)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(allergie.substanz).font(.subheadline.bold())
                if !allergie.typ.isEmpty {
                    Text(allergie.typ).font(.caption).foregroundStyle(.secondary)
                }
                if !allergie.reaktion.isEmpty {
                    Text(allergie.reaktion).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            AllergieSchwereBadge(schwere: allergie.schwere)
        }
        .padding(.vertical, 4)
    }

    private var allergieSymbol: String {
        switch allergie.schwere {
        case "Lebensbedrohlich": return "exclamationmark.triangle.fill"
        case "Schwer": return "xmark.circle.fill"
        case "Mittel": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private var allergieFarbe: Color {
        switch allergie.schwere {
        case "Lebensbedrohlich": return .red
        case "Schwer": return .orange
        case "Mittel": return .yellow
        default: return .secondary
        }
    }
}

// MARK: - Form

struct AllergieForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var allergie: Allergie? = nil

    @State private var substanz = ""
    @State private var typ = ""
    @State private var reaktion = ""
    @State private var schwere = "Mittel"

    private let typen = ["Medikament", "Nahrungsmittel", "Umwelt", "Kontakt", "Sonstiges"]
    private let schwereGrade = ["Leicht", "Mittel", "Schwer", "Lebensbedrohlich"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Allergen / Substanz") {
                    TextField("Substanz / Allergen", text: $substanz)
                    Picker("Typ", selection: $typ) {
                        Text("Bitte wählen").tag("")
                        ForEach(typen, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Reaktion & Schwere") {
                    TextField("Reaktion (z.B. Hautausschlag, Atemnot)", text: $reaktion, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Schwere", selection: $schwere) {
                        ForEach(schwereGrade, id: \.self) { grad in
                            HStack {
                                AllergieSchwereBadge(schwere: grad)
                            }
                            .tag(grad)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(allergie == nil ? "Neue Allergie" : "Allergie bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(substanz.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { laden() }
    }

    private func laden() {
        guard let a = allergie else { return }
        substanz = a.substanz
        typ = a.typ
        reaktion = a.reaktion
        schwere = a.schwere
    }

    private func speichern() {
        if let a = allergie {
            a.substanz = substanz
            a.typ = typ
            a.reaktion = reaktion
            a.schwere = schwere
        } else {
            let neu = Allergie(substanz: substanz, typ: typ, reaktion: reaktion, schwere: schwere)
            modelContext.insert(neu)
        }
        dismiss()
    }
}

// MARK: - Shared Badge

struct AllergieSchwereBadge: View {
    let schwere: String
    var body: some View {
        Text(schwere)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(farbe.opacity(0.2))
            .foregroundStyle(farbe)
            .clipShape(Capsule())
    }
    private var farbe: Color {
        switch schwere {
        case "Leicht": return .green
        case "Mittel": return .yellow
        case "Schwer": return .orange
        case "Lebensbedrohlich": return .red
        default: return .secondary
        }
    }
}
