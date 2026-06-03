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
                List {
                    ProfilInhaltView(profil: profil)
                }
                .navigationTitle("Profil")
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
    case diagnose, allergie, arzt, notfallKontakt
    var id: Int {
        switch self {
        case .diagnose:       return 1
        case .allergie:       return 2
        case .arzt:           return 3
        case .notfallKontakt: return 4
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
        // Single sheet entry point — eliminates the open/close race condition
        // caused by multiple .sheet modifiers on sibling Section views.
        .sheet(item: $aktivesFormular) { formular in
            switch formular {
            case .diagnose:
                DiagnoseFormView { bezeichnung, datum, notizen in
                    profil.diagnosen.append(Diagnose(bezeichnung: bezeichnung, datum: datum, notizen: notizen))
                }
            case .allergie:
                AllergieFormView { substanz, typ, reaktion, schwere in
                    profil.allergien.append(Allergie(substanz: substanz, typ: typ, reaktion: reaktion, schwere: schwere))
                }
            case .arzt:
                ArztFormView { name, fachgebiet, praxis, telefon, email, istHausarzt, notizen in
                    profil.aerzte.append(ArztKontakt(name: name, fachgebiet: fachgebiet, praxis: praxis,
                                                     telefon: telefon, email: email,
                                                     istHausarzt: istHausarzt, notizen: notizen))
                }
            case .notfallKontakt:
                NotfallKontaktFormView { name, phone, beziehung in
                    profil.notfallkontakte.append(NotfallKontakt(name: name, phone: phone, beziehung: beziehung))
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.bezeichnung).font(.headline)
                    if let datum = d.datum {
                        Text(datum, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                    if !d.notizen.isEmpty {
                        Text(d.notizen).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { profil.diagnosen.remove(atOffsets: $0) }
            Button("Diagnose hinzufügen") { aktivesFormular = .diagnose }
        } header: { Text("Diagnosen") }
    }

    // MARK: - Allergien

    private var allergienSektion: some View {
        Section {
            ForEach(profil.allergien as [Allergie]) { a in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(a.substanz).font(.headline)
                        Spacer()
                        AllergieSchwereBadge(schwere: a.schwere)
                    }
                    if !a.typ.isEmpty     { Text(a.typ).font(.caption).foregroundStyle(.secondary) }
                    if !a.reaktion.isEmpty { Text(a.reaktion).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .onDelete { profil.allergien.remove(atOffsets: $0) }
            Button("Allergie hinzufügen") { aktivesFormular = .allergie }
        } header: { Text("Allergien & Unverträglichkeiten") }
    }

    // MARK: - Ärzte

    private var aerzte: some View {
        Section {
            ForEach(profil.aerzte as [ArztKontakt]) { a in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(a.name).font(.headline)
                        if a.istHausarzt {
                            Label("Hausarzt", systemImage: "staroflife.fill")
                                .font(.caption).foregroundStyle(.blue)
                        }
                    }
                    if !a.fachgebiet.isEmpty { Text(a.fachgebiet).font(.subheadline).foregroundStyle(.secondary) }
                    if !a.praxis.isEmpty     { Text(a.praxis).font(.caption).foregroundStyle(.secondary) }
                    if !a.telefon.isEmpty    { Label(a.telefon, systemImage: "phone").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .onDelete { profil.aerzte.remove(atOffsets: $0) }
            Button("Arzt hinzufügen") { aktivesFormular = .arzt }
        } header: { Text("Ärzte") }
    }

    // MARK: - Notfallkontakte

    private var notfallkontakte: some View {
        Section {
            ForEach(profil.notfallkontakte as [NotfallKontakt]) { k in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.name).font(.headline)
                        if !k.beziehung.isEmpty { Text(k.beziehung).font(.caption).foregroundStyle(.secondary) }
                        if !k.phone.isEmpty     { Text(k.phone).font(.caption).foregroundStyle(.secondary) }
                    }
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
            Button("Manuell hinzufügen") { aktivesFormular = .notfallKontakt }
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
    @State private var bezeichnung = ""
    @State private var datum: Date? = nil
    @State private var notizen = ""
    @State private var datumAktiv = false
    let onSave: (String, Date?, String) -> Void

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
            .navigationTitle("Neue Diagnose")
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
    @State private var substanz = ""
    @State private var typ = ""
    @State private var reaktion = ""
    @State private var schwere = "Mittel"
    let onSave: (String, String, String, String) -> Void
    private let typen = ["Medikament", "Nahrungsmittel", "Umwelt", "Sonstiges"]
    private let schwereGrade = ["Leicht", "Mittel", "Schwer", "Lebensbedrohlich"]

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
            .navigationTitle("Neue Allergie")
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
    @State private var name = ""
    @State private var fachgebiet = ""
    @State private var praxis = ""
    @State private var telefon = ""
    @State private var email = ""
    @State private var istHausarzt = false
    @State private var notizen = ""
    let onSave: (String, String, String, String, String, Bool, String) -> Void

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
            .navigationTitle("Neuer Arzt")
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
    @State private var name = ""
    @State private var phone = ""
    @State private var beziehung = ""
    let onSave: (String, String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Telefon", text: $phone).keyboardType(.phonePad)
                TextField("Beziehung (z.B. Partner)", text: $beziehung)
            }
            .navigationTitle("Notfallkontakt")
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
