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
        .navigationBarTitleDisplayMode(.large)
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
    @State private var schritt = 0
    private let isEdit: Bool
    let onSave: (String, String, String, String, String, String, Bool, String) -> Void

    private let TINT: Color = .indigo
    private let maxSchritt = 1
    private let pflichtSchritte: Set<Int> = [0]

    private let fachrichtungen = ["Allgemeinmedizin", "Innere Medizin", "Rheumatologie",
                                   "Neurologie", "Kardiologie", "Orthopädie", "Dermatologie",
                                   "Diabetologie"]

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

    private var kannWeiter: Bool { !name.isEmpty || !praxis.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 3)
                        Capsule().fill(TINT)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.top, 10)

                schrittInhalt
                    .frame(maxHeight: .infinity)

                navigationsLeiste
            }
            .navigationTitle(isEdit ? "Arzt bearbeiten" : "Neuer Arzt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            ScrollView {
                VStack(spacing: 20) {
                    schrittHeader(symbol: "stethoscope", titel: "Arzt",
                                  untertitel: "Name und Fachrichtung des Arztes")

                    // Name & Praxis card
                    VStack(spacing: 0) {
                        TextField("Name des Arztes", text: $name)
                            .font(.subheadline).padding(16)
                        Divider().padding(.leading, 16)
                        TextField("Praxis / Klinik", text: $praxis)
                            .font(.subheadline).padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Fachrichtung grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fachrichtung").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(fachrichtungen, id: \.self) { opt in
                                let sel = fachgebiet == opt
                                Button { fachgebiet = opt } label: {
                                    Text(opt).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(sel ? TINT : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(sel ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .animation(.easeInOut(duration: 0.15), value: sel)
                                }.buttonStyle(.plain)
                            }
                        }
                        // Custom fachgebiet field if none of the grid options match
                        TextField("Oder eigene Fachrichtung", text: $fachgebiet)
                            .font(.subheadline).padding(16)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        default:
            ScrollView {
                VStack(spacing: 20) {
                    schrittHeader(symbol: "phone.fill", titel: "Kontakt",
                                  untertitel: "Adresse, Telefon und weitere Infos")

                    // Address & contact card
                    VStack(spacing: 0) {
                        TextField("Adresse", text: $adresse)
                            .font(.subheadline).padding(16)
                        Divider().padding(.leading, 16)
                        TextField("Telefon", text: $telefon)
                            .keyboardType(.phonePad)
                            .font(.subheadline).padding(16)
                        Divider().padding(.leading, 16)
                        TextField("E-Mail", text: $email)
                            .keyboardType(.emailAddress)
                            .font(.subheadline).padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Hausarzt toggle
                    VStack(spacing: 0) {
                        Toggle("Hausarzt", isOn: $istHausarzt)
                            .font(.subheadline).padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Notizen card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Notizen")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 12)
                        TextEditor(text: $notizen)
                            .font(.subheadline)
                            .frame(minHeight: 80)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        }
    }

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button { withAnimation { schritt -= 1 } } label: {
                    Text("Zurück").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Überspringen").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button { guard kannWeiter else { return }; withAnimation { schritt += 1 } } label: {
                    Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(kannWeiter ? TINT : Color.secondary, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(!kannWeiter)
            } else {
                Button {
                    onSave(name, praxis, fachgebiet, adresse, telefon, email, istHausarzt, notizen)
                    dismiss()
                } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(TINT, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
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
