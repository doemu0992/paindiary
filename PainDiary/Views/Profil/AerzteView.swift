import SwiftUI
import SwiftData

struct AerzteView: View {
    let profil: Benutzerprofil
    @Environment(\.modelContext) private var modelContext
    @State private var bearbeitet: ArztKontakt? = nil
    @State private var zeigeNeu = false
#if os(iOS)
    @State private var zeigeAdressbuch = false
    @State private var zeigeArztSuche = false
#endif

    private var aerzte: [ArztKontakt] { profil.aerzte ?? [] }

    var body: some View {
        List {
            if aerzte.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Ärzte",
                        systemImage: "stethoscope",
                        description: Text("Tippe auf + um einen Arzt einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(aerzte) { a in
                        ArztZeile(arzt: a)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = a }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(a)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                Button { bearbeitet = a } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { indexSet in
                        indexSet.map { aerzte[$0] }.forEach { modelContext.delete($0) }
                    }
                }
            }
            Section {
#if os(iOS)
                Button { zeigeArztSuche = true } label: {
                    Label("Suchen", systemImage: "magnifyingglass")
                }
                Button { zeigeAdressbuch = true } label: {
                    Label("Aus Adressbuch wählen", systemImage: "person.crop.circle.badge.plus")
                }
#endif
                Button { zeigeNeu = true } label: {
                    Label("Manuell hinzufügen", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Ärzte")
        .sheet(item: $bearbeitet) { arzt in
            ArztFormView(existing: arzt) { name, praxis, fachgebiet, adresse, telefon, email, istHausarzt, notizen in
                arzt.name = name; arzt.praxis = praxis; arzt.fachgebiet = fachgebiet
                arzt.adresse = adresse; arzt.telefon = telefon; arzt.email = email
                arzt.istHausarzt = istHausarzt; arzt.notizen = notizen
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            ArztFormView { name, praxis, fachgebiet, adresse, telefon, email, istHausarzt, notizen in
                let neu = ArztKontakt(name: name, praxis: praxis, fachgebiet: fachgebiet,
                                      adresse: adresse, telefon: telefon, email: email,
                                      istHausarzt: istHausarzt, notizen: notizen)
                profil.aerzte = (profil.aerzte ?? []) + [neu]
            }
        }
#if os(iOS)
        .sheet(isPresented: $zeigeAdressbuch) {
            KontaktPickerView { daten in
                for d in daten {
                    let neu = ArztKontakt(name: d.name, praxis: d.praxis, fachgebiet: "",
                                          adresse: d.adresse, telefon: d.phone, email: d.email)
                    profil.aerzte = (profil.aerzte ?? []) + [neu]
                }
            }
        }
        .sheet(isPresented: $zeigeArztSuche) {
            ArztSucheSheet { praxis, adresse, telefon, name in
                let neu = ArztKontakt(name: name, praxis: praxis, fachgebiet: "",
                                      adresse: adresse, telefon: telefon, email: "")
                profil.aerzte = (profil.aerzte ?? []) + [neu]
            }
        }
#endif
    }
}

private struct ArztZeile: View {
    let arzt: ArztKontakt

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(arzt.name.isEmpty ? arzt.praxis : arzt.name)
                        .font(.headline)
                    if arzt.istHausarzt {
                        Label("Hausarzt", systemImage: "staroflife.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                if !arzt.name.isEmpty && !arzt.praxis.isEmpty {
                    Text(arzt.praxis).font(.subheadline).foregroundStyle(.secondary)
                }
                if !arzt.fachgebiet.isEmpty {
                    Text(arzt.fachgebiet).font(.caption).foregroundStyle(.secondary)
                }
                if !arzt.adresse.isEmpty {
                    Text(arzt.adresse).font(.caption).foregroundStyle(.secondary)
                }
                if !arzt.telefon.isEmpty {
                    Label(arzt.telefon, systemImage: "phone").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct ArztFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var praxis: String
    @State private var fachgebiet: String
    @State private var adresse: String
    @State private var telefon: String
    @State private var email: String
    @State private var istHausarzt: Bool
    @State private var notizen: String
    private let isEdit: Bool
    let onSave: (String, String, String, String, String, String, Bool, String) -> Void

    init(existing: ArztKontakt? = nil, onSave: @escaping (String, String, String, String, String, String, Bool, String) -> Void) {
        self.isEdit = existing != nil
        self.onSave = onSave
        _name        = State(initialValue: existing?.name ?? "")
        _praxis      = State(initialValue: existing?.praxis ?? "")
        _fachgebiet  = State(initialValue: existing?.fachgebiet ?? "")
        _adresse     = State(initialValue: existing?.adresse ?? "")
        _telefon     = State(initialValue: existing?.telefon ?? "")
        _email       = State(initialValue: existing?.email ?? "")
        _istHausarzt = State(initialValue: existing?.istHausarzt ?? false)
        _notizen     = State(initialValue: existing?.notizen ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Praxis / Klinik", text: $praxis)
                    TextField("Name des Arztes", text: $name)
                    TextField("Fachgebiet", text: $fachgebiet)
                    TextField("Adresse", text: $adresse)
                }
                Section {
                    TextField("Telefon", text: $telefon).keyboardType(.phonePad)
                    TextField("E-Mail", text: $email).keyboardType(.emailAddress)
                    Toggle("Hausarzt", isOn: $istHausarzt)
                }
                Section("Notizen") { TextEditor(text: $notizen).frame(minHeight: 60) }
            }
            .navigationTitle(isEdit ? "Arzt bearbeiten" : "Neuer Arzt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(name, praxis, fachgebiet, adresse, telefon, email, istHausarzt, notizen)
                        dismiss()
                    }
                    .disabled(name.isEmpty && praxis.isEmpty)
                }
            }
        }
    }
}
