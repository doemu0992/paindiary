import SwiftUI
import SwiftData

struct ProfilView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [Benutzerprofil]

    private var profil: Benutzerprofil {
        if let p = profile.first { return p }
        let neu = Benutzerprofil()
        modelContext.insert(neu)
        return neu
    }

    var body: some View {
        List {
            ProfilInhaltView(profil: profil)
        }
        .navigationTitle("Profil")
    }
}

private struct ProfilInhaltView: View {
    let profil: Benutzerprofil

    @State private var diagnoseFormAnzeigen = false
    @State private var allergieFormAnzeigen = false
    @State private var arztFormAnzeigen = false
    @State private var notfallFormAnzeigen = false

    var body: some View {
        persoenlicheDaten
        medizinischeDaten
        medikamenteLink
        diagnoseSektion
        allergienSektion
        aerzte
        notfallkontakte
        einstellungen
    }

    private var medikamenteLink: some View {
        Section {
            NavigationLink(destination: MedikamenteView()) {
                Label("Medikamente verwalten", systemImage: "pill.fill")
            }
        } header: {
            Text("Dauermedikation")
        }
    }

    private var persoenlicheDaten: some View {
        Section("Persönliche Daten") {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("\(Bindable(profil).vorname.wrappedValue) \(Bindable(profil).nachname.wrappedValue)")
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
                    get: { Bindable(profil).geburtsdatum.wrappedValue ?? Date() },
                    set: { Bindable(profil).geburtsdatum.wrappedValue = $0 }
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

    private var diagnoseSektion: some View {
        Section {
            ForEach(profil.diagnosen as [Diagnose]) { diagnose in
                VStack(alignment: .leading, spacing: 2) {
                    Text(diagnose.bezeichnung).font(.headline)
                    if let datum = diagnose.datum {
                        Text(datum, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                    if !diagnose.notizen.isEmpty {
                        Text(diagnose.notizen).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in
                indices.forEach { profil.diagnosen.remove(at: $0) }
            }
            Button("Diagnose hinzufügen") { diagnoseFormAnzeigen = true }
        } header: {
            Text("Diagnosen")
        }
        .sheet(isPresented: $diagnoseFormAnzeigen) {
            DiagnoseFormView { bezeichnung, datum, notizen in
                let neu = Diagnose(bezeichnung: bezeichnung, datum: datum, notizen: notizen)
                profil.diagnosen.append(neu)
            }
        }
    }

    private var allergienSektion: some View {
        Section {
            ForEach(profil.allergien as [Allergie]) { allergie in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(allergie.substanz).font(.headline)
                        Spacer()
                        AllergieSchwereBadge(schwere: allergie.schwere)
                    }
                    if !allergie.typ.isEmpty {
                        Text(allergie.typ).font(.caption).foregroundStyle(.secondary)
                    }
                    if !allergie.reaktion.isEmpty {
                        Text(allergie.reaktion).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in
                indices.forEach { profil.allergien.remove(at: $0) }
            }
            Button("Allergie hinzufügen") { allergieFormAnzeigen = true }
        } header: {
            Text("Allergien & Unverträglichkeiten")
        }
        .sheet(isPresented: $allergieFormAnzeigen) {
            AllergieFormView { substanz, typ, reaktion, schwere in
                let neu = Allergie(substanz: substanz, typ: typ, reaktion: reaktion, schwere: schwere)
                profil.allergien.append(neu)
            }
        }
    }

    private var aerzte: some View {
        Section {
            ForEach(profil.aerzte as [ArztKontakt]) { arzt in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(arzt.name).font(.headline)
                        if arzt.istHausarzt {
                            Label("Hausarzt", systemImage: "staroflife.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    if !arzt.fachgebiet.isEmpty {
                        Text(arzt.fachgebiet).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !arzt.praxis.isEmpty {
                        Text(arzt.praxis).font(.caption).foregroundStyle(.secondary)
                    }
                    if !arzt.telefon.isEmpty {
                        Label(arzt.telefon, systemImage: "phone")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in
                indices.forEach { profil.aerzte.remove(at: $0) }
            }
            Button("Arzt hinzufügen") { arztFormAnzeigen = true }
        } header: {
            Text("Ärzte")
        }
        .sheet(isPresented: $arztFormAnzeigen) {
            ArztFormView { name, fachgebiet, praxis, telefon, email, istHausarzt, notizen in
                let neu = ArztKontakt(name: name, fachgebiet: fachgebiet, praxis: praxis,
                                     telefon: telefon, email: email,
                                     istHausarzt: istHausarzt, notizen: notizen)
                profil.aerzte.append(neu)
            }
        }
    }

    private var notfallkontakte: some View {
        Section {
            ForEach(profil.notfallkontakte as [NotfallKontakt]) { kontakt in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kontakt.name).font(.headline)
                        if !kontakt.beziehung.isEmpty {
                            Text(kontakt.beziehung).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !kontakt.phone.isEmpty {
                        Link(destination: URL(string: "tel:\(kontakt.phone.filter { $0.isNumber || $0 == "+" })")!) {
                            Image(systemName: "phone.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .onDelete { indices in
                indices.forEach { profil.notfallkontakte.remove(at: $0) }
            }
            Button("Notfallkontakt hinzufügen") { notfallFormAnzeigen = true }
        } header: {
            Text("Notfallkontakte")
        }
        .sheet(isPresented: $notfallFormAnzeigen) {
            NotfallKontaktFormView { name, phone, beziehung in
                let neu = NotfallKontakt(name: name, phone: phone, beziehung: beziehung)
                profil.notfallkontakte.append(neu)
            }
        }
    }

    private var einstellungen: some View {
        Section("Einstellungen") {
            Toggle("Zyklus-Tracking", isOn: Bindable(profil).zyklusTrackingAktiv)
            Toggle("Biometrische Sperre", isOn: Bindable(profil).biometrischesLockAktiv)
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
                        get: { datum ?? Date() },
                        set: { datum = $0 }
                    ), displayedComponents: .date)
                }
                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle("Neue Diagnose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(bezeichnung, datumAktiv ? datum : nil, notizen)
                        dismiss()
                    }
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
                    Button("Speichern") {
                        onSave(substanz, typ, reaktion, schwere)
                        dismiss()
                    }
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
                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle("Neuer Arzt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(name, fachgebiet, praxis, telefon, email, istHausarzt, notizen)
                        dismiss()
                    }
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
                    Button("Speichern") {
                        onSave(name, phone, beziehung)
                        dismiss()
                    }
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
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
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
