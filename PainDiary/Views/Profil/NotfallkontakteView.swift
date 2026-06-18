import SwiftUI
import SwiftData

struct NotfallkontakteView: View {
    let profil: Benutzerprofil
    @Environment(\.modelContext) private var modelContext
    @State private var bearbeitet: NotfallKontakt? = nil
    @State private var zeigeNeu = false
#if os(iOS)
    @State private var zeigeAdressbuch = false
#endif

    private var kontakte: [NotfallKontakt] { profil.notfallkontakte ?? [] }

    var body: some View {
        List {
            if kontakte.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Notfallkontakte",
                        systemImage: "phone.fill",
                        description: Text("Tippe auf + um einen Notfallkontakt einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(kontakte) { k in
                        NotfallKontaktZeile(kontakt: k)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = k }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(k)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                Button { bearbeitet = k } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { indexSet in
                        indexSet.map { kontakte[$0] }.forEach { modelContext.delete($0) }
                    }
                }
            }
            Section {
#if os(iOS)
                Button { zeigeAdressbuch = true } label: {
                    Label("Aus Adressbuch wählen", systemImage: "person.crop.circle.badge.plus")
                }
#endif
                Button { zeigeNeu = true } label: {
                    Label("Manuell hinzufügen", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Notfallkontakte")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $bearbeitet) { kontakt in
            NotfallKontaktFormView(existing: kontakt) { name, phone, beziehung in
                kontakt.name = name; kontakt.phone = phone; kontakt.beziehung = beziehung
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            NotfallKontaktFormView { name, phone, beziehung in
                let neu = NotfallKontakt(name: name, phone: phone, beziehung: beziehung)
                profil.notfallkontakte = (profil.notfallkontakte ?? []) + [neu]
            }
        }
#if os(iOS)
        .sheet(isPresented: $zeigeAdressbuch) {
            KontaktPickerView { daten in
                for d in daten {
                    let neu = NotfallKontakt(name: d.name, phone: d.phone, beziehung: "")
                    profil.notfallkontakte = (profil.notfallkontakte ?? []) + [neu]
                }
            }
        }
#endif
    }
}

private struct NotfallKontaktZeile: View {
    let kontakt: NotfallKontakt

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(kontakt.name).font(.headline)
                if !kontakt.beziehung.isEmpty {
                    Text(kontakt.beziehung).font(.caption).foregroundStyle(.secondary)
                }
                if !kontakt.phone.isEmpty {
                    Label(kontakt.phone, systemImage: "phone").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !kontakt.phone.isEmpty {
                Link(destination: URL(string: "tel:\(kontakt.phone.filter { $0.isNumber || $0 == "+" })")!) {
                    Image(systemName: "phone.circle.fill").font(.title2).foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct NotfallKontaktFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    @State private var beziehung: String
    private let isEdit: Bool
    let onSave: (String, String, String) -> Void

    private let TINT: Color = .red
    private let beziehungsOptionen = ["Partner", "Elternteil", "Kind", "Freund", "Arzt", "Sonstiges"]

    init(existing: NotfallKontakt? = nil, onSave: @escaping (String, String, String) -> Void) {
        self.isEdit = existing != nil
        self.onSave = onSave
        _name      = State(initialValue: existing?.name ?? "")
        _phone     = State(initialValue: existing?.phone ?? "")
        _beziehung = State(initialValue: existing?.beziehung ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                schrittInhalt
                    .frame(maxHeight: .infinity)

                speichernLeiste
            }
            .navigationTitle(isEdit ? "Kontakt bearbeiten" : "Notfallkontakt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private var schrittInhalt: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "person.crop.circle.badge.plus", titel: "Notfallkontakt",
                              untertitel: "Name, Telefonnummer und Beziehung")

                // Name & Telefon card
                VStack(spacing: 0) {
                    TextField("Name", text: $name)
                        .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Telefon", text: $phone)
                        .keyboardType(.phonePad)
                        .font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12))

                // Beziehung button grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("Beziehung").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(beziehungsOptionen, id: \.self) { opt in
                            let sel = beziehung == opt
                            Button { beziehung = opt } label: {
                                Text(opt).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(sel ? TINT : Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(sel ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .animation(.easeInOut(duration: 0.15), value: sel)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var speichernLeiste: some View {
        Button { onSave(name, phone, beziehung); dismiss() } label: {
            Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(name.isEmpty ? Color.secondary : TINT, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
        .padding()
        .background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(TINT)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
    }
}
