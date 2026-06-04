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
#if os(iOS)
    @State private var adressbuchAnzeigen = false
    @State private var photoItem: PhotosPickerItem? = nil
#endif

    var body: some View {
        List {
            persoenlicheDaten
            medizinischeDaten
            medikamenteLink
            midasLink
            zyklusLink
            diagnoseSektion
            allergienSektion
            aerzte
            notfallkontakte
            einstellungen
        }
        .navigationTitle("Profil")
        .sheet(item: $aktivesFormular) { formular in
            switch formular {
            case .diagnose(let existing):
                DiagnoseFormView(existing: existing) { bezeichnung, datum, notizen in
                    if let d = existing {
                        d.bezeichnung = bezeichnung; d.datum = datum; d.notizen = notizen
                    } else {
                        profil.diagnosen.append(Diagnose(bezeichnung: bezeichnung, datum: datum, notizen: notizen))
                    }
                }
            case .allergie(let existing):
                AllergieFormView(existing: existing) { substanz, typ, reaktion, schwere in
                    if let a = existing {
                        a.substanz = substanz; a.typ = typ; a.reaktion = reaktion; a.schwere = schwere
                    } else {
                        profil.allergien.append(Allergie(substanz: substanz, typ: typ, reaktion: reaktion, schwere: schwere))
                    }
                }
            case .arzt(let existing):
                ArztFormView(existing: existing) { name, fachgebiet, praxis, telefon, email, istHausarzt, notizen in
                    if let a = existing {
                        a.name = name; a.fachgebiet = fachgebiet; a.praxis = praxis
                        a.telefon = telefon; a.email = email; a.istHausarzt = istHausarzt; a.notizen = notizen
                    } else {
                        profil.aerzte.append(ArztKontakt(name: name, fachgebiet: fachgebiet, praxis: praxis,
                                                         telefon: telefon, email: email,
                                                         istHausarzt: istHausarzt, notizen: notizen))
                    }
                }
            case .notfallKontakt(let existing):
                NotfallKontaktFormView(existing: existing) { name, phone, beziehung in
                    if let k = existing {
                        k.name = name; k.phone = phone; k.beziehung = beziehung
                    } else {
                        profil.notfallkontakte.append(NotfallKontakt(name: name, phone: phone, beziehung: beziehung))
                    }
                }
            }
        }
#if os(iOS)
        .sheet(isPresented: $adressbuchAnzeigen) {
            KontaktPickerView { daten in
                for d in daten {
                    profil.notfallkontakte.append(NotfallKontakt(name: d.name, phone: d.phone, beziehung: ""))
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    profil.fotoData = data
                }
            }
        }
#endif
        .onAppear {
            if profil.geschlecht == "Nicht angegeben" { profil.geschlecht = "" }
            if profil.blutgruppe == "Unbekannt" { profil.blutgruppe = "" }
        }
    }

    // MARK: - Persönliche Daten

    private var persoenlicheDaten: some View {
        Section("Persönliche Daten") {
            HStack {
                Spacer()
                VStack(spacing: 10) {
#if os(iOS)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        profilBild
                    }
                    .buttonStyle(.plain)
                    Text("Foto ändern")
                        .font(.caption).foregroundStyle(.secondary)
#else
                    profilBild
#endif
                    Text("\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces))
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)

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
    }

    @ViewBuilder
    private var profilBild: some View {
#if os(iOS)
        if let data = profil.fotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        } else {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "camera.fill").font(.system(size: 12)).foregroundStyle(.white))
                    .offset(x: 28, y: 28)
            }
        }
#else
        Image(systemName: "person.circle.fill")
            .font(.system(size: 80))
            .foregroundStyle(.secondary)
#endif
    }

    // MARK: - Medizinische Daten

    private var medizinischeDaten: some View {
        Section("Medizinische Daten") {
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

    // MARK: - Navigation links

    private var medikamenteLink: some View {
        Section {
            NavigationLink(destination: MedikamenteView()) {
                Label("Medikamente verwalten", systemImage: "pill.fill")
            }
        } header: { Text("Dauermedikation") }
    }

    private var midasLink: some View {
        Section {
            NavigationLink(destination: MIDASView()) {
                Label("MIDAS-Fragebogen", systemImage: "brain.head.profile")
            }
        } header: { Text("Kopfschmerz-Assessment") }
    }

    private var zyklusLink: some View {
        Section {
            NavigationLink(destination: ZyklusView()) {
                Label("Zyklus-Tracking", systemImage: "drop.fill")
            }
        } header: { Text("Zyklus") }
    }

    // MARK: - Diagnosen

    private var diagnoseSektion: some View {
        Section {
            ForEach(profil.diagnosen as [Diagnose]) { d in
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
            .onDelete { profil.diagnosen.remove(atOffsets: $0) }
            Button("Diagnose hinzufügen") { aktivesFormular = .diagnose(nil) }
        } header: { Text("Diagnosen") }
    }

    // MARK: - Allergien

    private var allergienSektion: some View {
        Section {
            ForEach(profil.allergien as [Allergie]) { a in
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
            .onDelete { profil.allergien.remove(atOffsets: $0) }
            Button("Allergie hinzufügen") { aktivesFormular = .allergie(nil) }
        } header: { Text("Allergien & Unverträglichkeiten") }
    }

    // MARK: - Ärzte

    private var aerzte: some View {
        Section {
            ForEach(profil.aerzte as [ArztKontakt]) { a in
                Button { aktivesFormular = .arzt(a) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(a.name).font(.headline).foregroundStyle(.primary)
                                if a.istHausarzt {
                                    Label("Hausarzt", systemImage: "staroflife.fill")
                                        .font(.caption).foregroundStyle(.blue)
                                }
                            }
                            if !a.fachgebiet.isEmpty { Text(a.fachgebiet).font(.subheadline).foregroundStyle(.secondary) }
                            if !a.praxis.isEmpty     { Text(a.praxis).font(.caption).foregroundStyle(.secondary) }
                            if !a.telefon.isEmpty    { Label(a.telefon, systemImage: "phone").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { profil.aerzte.remove(atOffsets: $0) }
            Button("Arzt hinzufügen") { aktivesFormular = .arzt(nil) }
        } header: { Text("Ärzte") }
    }

    // MARK: - Notfallkontakte

    private var notfallkontakte: some View {
        Section {
            ForEach(profil.notfallkontakte as [NotfallKontakt]) { k in
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
            .onDelete { profil.notfallkontakte.remove(atOffsets: $0) }
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
            Toggle("Biometrische Sperre", isOn: Bindable(profil).biometrischesLockAktiv)
            NavigationLink(destination: EinstellungenView()) {
                Label("App-Einstellungen", systemImage: "gearshape")
            }
        }
    }
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
    @State private var fachgebiet: String
    @State private var praxis: String
    @State private var telefon: String
    @State private var email: String
    @State private var istHausarzt: Bool
    @State private var notizen: String
    private let isEdit: Bool
    let onSave: (String, String, String, String, String, Bool, String) -> Void

    init(existing: ArztKontakt? = nil, onSave: @escaping (String, String, String, String, String, Bool, String) -> Void) {
        self.isEdit = existing != nil
        self.onSave = onSave
        _name        = State(initialValue: existing?.name ?? "")
        _fachgebiet  = State(initialValue: existing?.fachgebiet ?? "")
        _praxis      = State(initialValue: existing?.praxis ?? "")
        _telefon     = State(initialValue: existing?.telefon ?? "")
        _email       = State(initialValue: existing?.email ?? "")
        _istHausarzt = State(initialValue: existing?.istHausarzt ?? false)
        _notizen     = State(initialValue: existing?.notizen ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Fachgebiet", text: $fachgebiet)
                TextField("Praxis / Adresse", text: $praxis)
                TextField("Telefon", text: $telefon).keyboardType(.phonePad)
                TextField("E-Mail", text: $email).keyboardType(.emailAddress)
                Toggle("Hausarzt", isOn: $istHausarzt)
                Section("Notizen") { TextEditor(text: $notizen).frame(minHeight: 60) }
            }
            .navigationTitle(isEdit ? "Arzt bearbeiten" : "Neuer Arzt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave(name, fachgebiet, praxis, telefon, email, istHausarzt, notizen); dismiss() }
                        .disabled(name.isEmpty)
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
