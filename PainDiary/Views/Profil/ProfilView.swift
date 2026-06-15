import SwiftUI
import SwiftData
#if os(iOS)
import PhotosUI
#endif

struct ProfilView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [Benutzerprofil]

    var body: some View {
        Group {
            if let profil = profile.first {
                ProfilInhaltView(profil: profil)
            } else {
                ProgressView("Lade Profil…")
                    .navigationTitle("Profil")
            }
        }
        .onAppear {
            if profile.isEmpty {
                modelContext.insert(Benutzerprofil())
            }
        }
    }
}

// MARK: - Sheet enum

private enum ProfilFormular: Identifiable {
    case diagnose(Diagnose?)
    case allergie(Allergie?)
    case arzt(ArztKontakt?)
    case notfallKontakt(NotfallKontakt?)

    var id: String {
        switch self {
        case .diagnose(let d):       return d.map { "d-\(ObjectIdentifier($0))" } ?? "d-new"
        case .allergie(let a):       return a.map { "a-\(ObjectIdentifier($0))" } ?? "a-new"
        case .arzt(let a):           return a.map { "arzt-\(ObjectIdentifier($0))" } ?? "arzt-new"
        case .notfallKontakt(let k): return k.map { "nk-\(ObjectIdentifier($0))" } ?? "nk-new"
        }
    }
}

// MARK: - Content

private struct ProfilInhaltView: View {
    let profil: Benutzerprofil
    @State private var aktivesFormular: ProfilFormular? = nil
    @State private var stammdatenAnzeigen = false
#if os(iOS)
    @State private var adressbuchAnzeigen = false
    @State private var adressbuchArztAnzeigen = false
    @State private var arztSucheAnzeigen = false
#endif

    var body: some View {
        List {
            heroHeader
            gesundheitSektion
            diagnoseSektion
            allergienSektion
            aerzte
            notfallkontakte
            einstellungen
        }
        .navigationTitle("Profil")
        .sheet(isPresented: $stammdatenAnzeigen) {
            StammdatenSheet(profil: profil)
        }
        .sheet(item: $aktivesFormular) { formular in
            switch formular {
            case .diagnose(let existing):
                DiagnoseFormView(existing: existing) { bezeichnung, datum, notizen in
                    if let d = existing {
                        d.bezeichnung = bezeichnung; d.datum = datum; d.notizen = notizen
                    } else {
                        profil.diagnosen = (profil.diagnosen ?? []) + [Diagnose(bezeichnung: bezeichnung, datum: datum, notizen: notizen)]
                    }
                }
            case .allergie(let existing):
                AllergieFormView(existing: existing) { substanz, typ, reaktion, schwere in
                    if let a = existing {
                        a.substanz = substanz; a.typ = typ; a.reaktion = reaktion; a.schwere = schwere
                    } else {
                        profil.allergien = (profil.allergien ?? []) + [Allergie(substanz: substanz, typ: typ, reaktion: reaktion, schwere: schwere)]
                    }
                }
            case .arzt(let existing):
                ArztFormView(existing: existing) { name, praxis, fachgebiet, adresse, telefon, email, istHausarzt, notizen in
                    if let a = existing {
                        a.name = name; a.praxis = praxis; a.fachgebiet = fachgebiet; a.adresse = adresse
                        a.telefon = telefon; a.email = email; a.istHausarzt = istHausarzt; a.notizen = notizen
                    } else {
                        profil.aerzte = (profil.aerzte ?? []) + [ArztKontakt(name: name, praxis: praxis,
                                                         fachgebiet: fachgebiet, adresse: adresse,
                                                         telefon: telefon, email: email,
                                                         istHausarzt: istHausarzt, notizen: notizen)]
                    }
                }
            case .notfallKontakt(let existing):
                NotfallKontaktFormView(existing: existing) { name, phone, beziehung in
                    if let k = existing {
                        k.name = name; k.phone = phone; k.beziehung = beziehung
                    } else {
                        profil.notfallkontakte = (profil.notfallkontakte ?? []) + [NotfallKontakt(name: name, phone: phone, beziehung: beziehung)]
                    }
                }
            }
        }
#if os(iOS)
        .sheet(isPresented: $adressbuchAnzeigen) {
            KontaktPickerView { daten in
                for d in daten {
                    profil.notfallkontakte = (profil.notfallkontakte ?? []) + [NotfallKontakt(name: d.name, phone: d.phone, beziehung: "")]
                }
            }
        }
        .sheet(isPresented: $adressbuchArztAnzeigen) {
            KontaktPickerView { daten in
                for d in daten {
                    profil.aerzte = (profil.aerzte ?? []) + [ArztKontakt(name: d.name, praxis: d.praxis, fachgebiet: "", adresse: d.adresse, telefon: d.phone, email: d.email)]
                }
            }
        }
        .sheet(isPresented: $arztSucheAnzeigen) {
            ArztSucheSheet { praxis, adresse, telefon, name in
                profil.aerzte = (profil.aerzte ?? []) + [ArztKontakt(name: name, praxis: praxis, fachgebiet: "", adresse: adresse, telefon: telefon, email: "")]
            }
        }
#endif
        .onAppear {
            if profil.geschlecht == "Nicht angegeben" { profil.geschlecht = "" }
            if profil.blutgruppe == "Unbekannt" { profil.blutgruppe = "" }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        Section {
            Button { stammdatenAnzeigen = true } label: {
                HStack(spacing: 14) {
                    profilBildKlein
                    VStack(alignment: .leading, spacing: 5) {
                        let name = "\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces)
                        Text(name.isEmpty ? "Profil einrichten" : name)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            if let geb = profil.geburtsdatum {
                                let alter = Calendar.current.dateComponents([.year], from: geb, to: Date()).year ?? 0
                                infoBadge("\(alter) J.", symbol: "person.fill", farbe: .blue)
                            }
                            if !profil.blutgruppe.isEmpty {
                                infoBadge(profil.blutgruppe, symbol: "drop.fill", farbe: .red)
                            }
                            if let bmi = profil.bmi {
                                infoBadge(String(format: "BMI %.1f", bmi), symbol: nil, farbe: bmiTint(bmi))
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var profilBildKlein: some View {
#if os(iOS)
        if let data = profil.fotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.15)).frame(width: 72, height: 72)
                Image(systemName: "person.fill").font(.system(size: 34)).foregroundStyle(.secondary)
                Circle().fill(Color.accentColor).frame(width: 24, height: 24)
                    .overlay(Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(.white))
                    .offset(x: 24, y: 24)
            }
        }
#else
        Image(systemName: "person.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(.secondary)
#endif
    }

    private func infoBadge(_ text: String, symbol: String?, farbe: Color) -> some View {
        HStack(spacing: 4) {
            if let sym = symbol {
                Image(systemName: sym).font(.caption2.bold())
            }
            Text(text).font(.caption.bold())
        }
        .foregroundStyle(farbe)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(farbe.opacity(0.12), in: Capsule())
    }

    private func bmiTint(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    // MARK: - Gesundheit

    private var gesundheitSektion: some View {
        Section("Gesundheit") {
            NavigationLink(destination: MedikamenteView()) {
                Label("Medikamente verwalten", systemImage: "pill.fill")
            }
            NavigationLink(destination: MIDASView()) {
                Label("MIDAS-Fragebogen", systemImage: "brain.head.profile")
            }
            NavigationLink(destination: ZyklusView()) {
                Label("Zyklus-Tracking", systemImage: "drop.fill")
            }
        }
    }

    // MARK: - Diagnosen

    private var diagnoseSektion: some View {
        Section {
            ForEach(profil.diagnosen ?? []) { d in
                Button { aktivesFormular = .diagnose(d) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.bezeichnung).font(.headline).foregroundStyle(.primary)
                            if let datum = d.datum {
                                Text(datum, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            if !d.notizen.isEmpty {
                                Text(d.notizen).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { var a = profil.diagnosen ?? []; a.remove(atOffsets: $0); profil.diagnosen = a }
            Button("Diagnose hinzufügen") { aktivesFormular = .diagnose(nil) }
        } header: { Text("Diagnosen") }
    }

    // MARK: - Allergien

    private var allergienSektion: some View {
        Section {
            ForEach(profil.allergien ?? []) { a in
                Button { aktivesFormular = .allergie(a) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(a.substanz).font(.headline).foregroundStyle(.primary)
                                Spacer()
                                AllergieSchwereBadge(schwere: a.schwere)
                            }
                            if !a.typ.isEmpty      { Text(a.typ).font(.caption).foregroundStyle(.secondary) }
                            if !a.reaktion.isEmpty { Text(a.reaktion).font(.caption).foregroundStyle(.secondary) }
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { var a = profil.allergien ?? []; a.remove(atOffsets: $0); profil.allergien = a }
            Button("Allergie hinzufügen") { aktivesFormular = .allergie(nil) }
        } header: { Text("Allergien & Unverträglichkeiten") }
    }

    // MARK: - Ärzte

    private var aerzte: some View {
        Section {
            ForEach(profil.aerzte ?? []) { a in
                Button { aktivesFormular = .arzt(a) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(a.name.isEmpty ? a.praxis : a.name).font(.headline).foregroundStyle(.primary)
                                if a.istHausarzt {
                                    Label("Hausarzt", systemImage: "staroflife.fill")
                                        .font(.caption).foregroundStyle(.blue)
                                }
                            }
                            if !a.name.isEmpty && !a.praxis.isEmpty { Text(a.praxis).font(.subheadline).foregroundStyle(.secondary) }
                            if !a.fachgebiet.isEmpty { Text(a.fachgebiet).font(.caption).foregroundStyle(.secondary) }
                            if !a.adresse.isEmpty    { Text(a.adresse).font(.caption).foregroundStyle(.secondary) }
                            if !a.telefon.isEmpty    { Label(a.telefon, systemImage: "phone").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { var a = profil.aerzte ?? []; a.remove(atOffsets: $0); profil.aerzte = a }
#if os(iOS)
            Button {
                arztSucheAnzeigen = true
            } label: {
                Label("Suchen", systemImage: "magnifyingglass")
            }
            Button {
                adressbuchArztAnzeigen = true
            } label: {
                Label("Aus Adressbuch wählen", systemImage: "person.crop.circle.badge.plus")
            }
#endif
            Button("Manuell hinzufügen") { aktivesFormular = .arzt(nil) }
        } header: { Text("Ärzte") }
    }

    // MARK: - Notfallkontakte

    private var notfallkontakte: some View {
        Section {
            ForEach(profil.notfallkontakte ?? []) { k in
                HStack {
                    Button { aktivesFormular = .notfallKontakt(k) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.name).font(.headline).foregroundStyle(.primary)
                            if !k.beziehung.isEmpty { Text(k.beziehung).font(.caption).foregroundStyle(.secondary) }
                            if !k.phone.isEmpty     { Text(k.phone).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if !k.phone.isEmpty {
                        Link(destination: URL(string: "tel:\(k.phone.filter { $0.isNumber || $0 == "+" })")!) {
                            Image(systemName: "phone.circle.fill").font(.title2).foregroundStyle(.green)
                        }
                    }
                }
            }
            .onDelete { var a = profil.notfallkontakte ?? []; a.remove(atOffsets: $0); profil.notfallkontakte = a }
#if os(iOS)
            Button {
                adressbuchAnzeigen = true
            } label: {
                Label("Aus Adressbuch wählen", systemImage: "person.crop.circle.badge.plus")
            }
#endif
            Button("Manuell hinzufügen") { aktivesFormular = .notfallKontakt(nil) }
        } header: { Text("Notfallkontakte") }
    }

    // MARK: - Einstellungen

    private var einstellungen: some View {
        Section("Einstellungen") {
            Toggle("Zyklus-Tracking", isOn: Bindable(profil).zyklusTrackingAktiv)
            NavigationLink(destination: EinstellungenView()) {
                Label("App-Einstellungen", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - Stammdaten Sheet

private struct StammdatenSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profil: Benutzerprofil
#if os(iOS)
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var zuschneidenBild: IdentifiableImage? = nil
#endif

    var body: some View {
        NavigationStack {
            Form {
#if os(iOS)
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            profilBild
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
#endif
                Section("Persönlich") {
                    LabeledContent("Vorname") {
                        TextField("Vorname", text: Bindable(profil).vorname)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Nachname") {
                        TextField("Nachname", text: Bindable(profil).nachname)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Geburtsdatum",
                        selection: Binding(
                            get: { profil.geburtsdatum ?? Date() },
                            set: { profil.geburtsdatum = $0 }
                        ),
                        displayedComponents: .date
                    )
                    Picker("Geschlecht", selection: Bindable(profil).geschlecht) {
                        Text("Weiblich").tag("Weiblich")
                        Text("Männlich").tag("Männlich")
                        Text("Divers").tag("Divers")
                        Text("Keine Angabe").tag("")
                    }
                    LabeledContent("Wohnort") {
                        TextField("Wohnort", text: Bindable(profil).wohnort)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Medizinisch") {
                    LabeledContent("Versicherung") {
                        TextField("Krankenversicherung", text: Bindable(profil).versicherung)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Versicherungs-Nr.") {
                        TextField("Nummer", text: Bindable(profil).versicherungsNummer)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Blutgruppe", selection: Bindable(profil).blutgruppe) {
                        ForEach(["", "A+", "A-", "B+", "B-", "AB+", "AB-", "0+", "0-"], id: \.self) {
                            Text($0.isEmpty ? "Unbekannt" : $0).tag($0)
                        }
                    }
                    LabeledContent("Gewicht (kg)") {
                        TextField("z.B. 70", value: Bindable(profil).gewichtKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Grösse (cm)") {
                        TextField("z.B. 170", value: Bindable(profil).groesseCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if let bmi = profil.bmi {
                        LabeledContent("BMI", value: String(format: "%.1f – %@", bmi, profil.bmiKategorie ?? ""))
                    }
                }
            }
            .navigationTitle("Stammdaten")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
#if os(iOS)
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        zuschneidenBild = IdentifiableImage(image: uiImage)
                    }
                }
            }
            .sheet(item: $zuschneidenBild) { wrapper in
                FotoZuschneidenView(uiImage: wrapper.image) { data in
                    profil.fotoData = data
                }
            }
#endif
        }
    }

#if os(iOS)
    @ViewBuilder
    private var profilBild: some View {
        if let data = profil.fotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.15)).frame(width: 88, height: 88)
                Image(systemName: "person.fill").font(.system(size: 40)).foregroundStyle(.secondary)
                Circle().fill(Color.accentColor).frame(width: 26, height: 26)
                    .overlay(Image(systemName: "camera.fill").font(.system(size: 12)).foregroundStyle(.white))
                    .offset(x: 28, y: 28)
            }
        }
    }
#endif
}

// MARK: - Form Views

private struct DiagnoseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bezeichnung: String
    @State private var datum: Date?
    @State private var notizen: String
    @State private var datumAktiv: Bool
    private let isEdit: Bool
    let onSave: (String, Date?, String) -> Void

    init(existing: Diagnose? = nil, onSave: @escaping (String, Date?, String) -> Void) {
        self.isEdit = existing != nil
        self.onSave = onSave
        _bezeichnung = State(initialValue: existing?.bezeichnung ?? "")
        _datum       = State(initialValue: existing?.datum)
        _notizen     = State(initialValue: existing?.notizen ?? "")
        _datumAktiv  = State(initialValue: existing?.datum != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Diagnose", text: $bezeichnung)
                Toggle("Datum bekannt", isOn: $datumAktiv)
                if datumAktiv {
                    DatePicker("Datum", selection: Binding(
                        get: { datum ?? Date() }, set: { datum = $0 }
                    ), displayedComponents: .date)
                }
                Section("Notizen") { TextEditor(text: $notizen).frame(minHeight: 60) }
            }
            .navigationTitle(isEdit ? "Diagnose bearbeiten" : "Neue Diagnose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave(bezeichnung, datumAktiv ? datum : nil, notizen); dismiss() }
                        .disabled(bezeichnung.isEmpty)
                }
            }
        }
    }
}

private struct AllergieFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var substanz: String
    @State private var typ: String
    @State private var reaktion: String
    @State private var schwere: String
    private let isEdit: Bool
    let onSave: (String, String, String, String) -> Void
    private let typen = ["Medikament", "Nahrungsmittel", "Umwelt", "Sonstiges"]
    private let schwereGrade = ["Leicht", "Mittel", "Schwer", "Lebensbedrohlich"]

    init(existing: Allergie? = nil, onSave: @escaping (String, String, String, String) -> Void) {
        self.isEdit = existing != nil
        self.onSave = onSave
        _substanz = State(initialValue: existing?.substanz ?? "")
        _typ      = State(initialValue: existing?.typ ?? "")
        _reaktion = State(initialValue: existing?.reaktion ?? "")
        _schwere  = State(initialValue: existing?.schwere ?? "Mittel")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Substanz / Allergen", text: $substanz)
                Picker("Typ", selection: $typ) {
                    Text("Bitte wählen").tag("")
                    ForEach(typen, id: \.self) { Text($0).tag($0) }
                }
                TextField("Reaktion", text: $reaktion)
                Picker("Schwere", selection: $schwere) {
                    ForEach(schwereGrade, id: \.self) { Text($0).tag($0) }
                }
            }
            .navigationTitle(isEdit ? "Allergie bearbeiten" : "Neue Allergie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave(substanz, typ, reaktion, schwere); dismiss() }
                        .disabled(substanz.isEmpty)
                }
            }
        }
    }
}

private struct ArztFormView: View {
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
                    Button("Speichern") { onSave(name, praxis, fachgebiet, adresse, telefon, email, istHausarzt, notizen); dismiss() }
                        .disabled(name.isEmpty && praxis.isEmpty)
                }
            }
        }
    }
}

private struct NotfallKontaktFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    @State private var beziehung: String
    private let isEdit: Bool
    let onSave: (String, String, String) -> Void

    init(existing: NotfallKontakt? = nil, onSave: @escaping (String, String, String) -> Void) {
        self.isEdit = existing != nil
        self.onSave = onSave
        _name      = State(initialValue: existing?.name ?? "")
        _phone     = State(initialValue: existing?.phone ?? "")
        _beziehung = State(initialValue: existing?.beziehung ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Telefon", text: $phone).keyboardType(.phonePad)
                TextField("Beziehung (z.B. Partner)", text: $beziehung)
            }
            .navigationTitle(isEdit ? "Kontakt bearbeiten" : "Notfallkontakt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave(name, phone, beziehung); dismiss() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Foto Zuschneiden

#if os(iOS)
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct FotoZuschneidenView: View {
    let uiImage: UIImage
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    private let frameSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale * pinchDelta)
                            .offset(
                                x: offset.width + dragDelta.width,
                                y: offset.height + dragDelta.height
                            )
                            .gesture(
                                DragGesture()
                                    .updating($dragDelta) { val, state, _ in state = val.translation }
                                    .onEnded { val in
                                        offset.width += val.translation.width
                                        offset.height += val.translation.height
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .updating($pinchDelta) { val, state, _ in state = val }
                                    .onEnded { val in
                                        scale = max(1.0, min(6.0, scale * val))
                                    }
                            )
                    }
                    .frame(width: frameSize, height: frameSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                    Spacer()
                    Text("Verschieben und zoomen")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Foto anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verwenden") {
                        if let data = renderCrop() { onSave(data) }
                        dismiss()
                    }.foregroundStyle(.white)
                }
            }
        }
    }

    private func renderCrop() -> Data? {
        let size = CGSize(width: frameSize, height: frameSize)
        let imgW = uiImage.size.width
        let imgH = uiImage.size.height
        let fillScale = max(frameSize / imgW, frameSize / imgH)
        let totalScale = fillScale * scale
        let drawW = imgW * totalScale
        let drawH = imgH * totalScale
        let x = (frameSize - drawW) / 2 + offset.width
        let y = (frameSize - drawH) / 2 + offset.height
        let renderer = UIGraphicsImageRenderer(size: size)
        let result = renderer.image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            uiImage.draw(in: CGRect(x: x, y: y, width: drawW, height: drawH))
        }
        return result.jpegData(compressionQuality: 0.85)
    }
}
#endif

// MARK: - Helper Views

private struct AllergieSchwereBadge: View {
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
