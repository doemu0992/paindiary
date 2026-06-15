import SwiftUI
import SwiftData

struct NotfallausweisView: View {
    @Query private var diagnosen: [Diagnose]
    @Query private var medikamente: [Dauermedikation]
    @Query private var aerzte: [ArztKontakt]
    @Query private var notfallKontakte: [NotfallKontakt]
    @Query private var profile: [Benutzerprofil]

    private var profil: Benutzerprofil? { profile.first }
    private var aktiveDiagnosen: [Diagnose] { diagnosen.filter { $0.aktiv } }
    private var aktiveMedikamente: [Dauermedikation] { medikamente.filter { $0.aktiv } }

    private var rheumatologe: ArztKontakt? {
        aerzte.first { $0.fachgebiet.localizedCaseInsensitiveContains("Rheumatolog") }
            ?? aerzte.first
    }

    private var ersterNotfallKontakt: NotfallKontakt? { notfallKontakte.first }

    private var zeigeImmunWarnung: Bool {
        aktiveMedikamente.contains { med in
            let typ = MedikamentTyp(rawValue: med.medikamentTyp)
            let istInjektion = typ?.istInjektion ?? false
            let nameLower = med.name.lowercased()
            let istBiologikum = nameLower.contains("biologik") || nameLower.contains("methotrexat")
            return istInjektion || istBiologikum
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerKarte

                if zeigeImmunWarnung {
                    warnungsKarte
                }

                if profil != nil {
                    persoenlicheDatenKarte
                }

                if !aktiveDiagnosen.isEmpty {
                    diagnoseKarte
                }

                if !aktiveMedikamente.isEmpty {
                    medikamenteKarte
                }

                if rheumatologe != nil {
                    arztKarte
                }

                if ersterNotfallKontakt != nil {
                    notfallKontaktKarte
                }
            }
            .padding()
        }
        .navigationTitle("Notfallausweis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ausweisText) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Karten

    private var headerKarte: some View {
        HStack(spacing: 14) {
            Image(systemName: "cross.case.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("Medizinischer Notfallausweis")
                    .font(.headline)
                Text("Rheumatologische Erkrankung")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let profil {
                    Text("\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces))
                        .font(.title3.bold())
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var warnungsKarte: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Immunsuppressiva").font(.subheadline.bold())
                Text("Kein lebend-attenuierter Impfstoff verabreichen (z.B. MMR, Varizellen, Gelbfieber).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    private var persoenlicheDatenKarte: some View {
        AusweisSektion(titel: "Persönliche Daten", symbol: "person.fill") {
            if let profil {
                if !profil.vorname.isEmpty || !profil.nachname.isEmpty {
                    AusweisZeile(label: "Name", wert: "\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces))
                }
                if let geb = profil.geburtsdatum {
                    AusweisZeile(label: "Geburtsdatum", wert: geb.formatted(date: .long, time: .omitted))
                }
                if !profil.blutgruppe.isEmpty {
                    AusweisZeile(label: "Blutgruppe", wert: profil.blutgruppe)
                }
                if !profil.versicherung.isEmpty {
                    AusweisZeile(label: "Versicherung", wert: profil.versicherung)
                }
                if !profil.versicherungsNummer.isEmpty {
                    AusweisZeile(label: "Vers.-Nr.", wert: profil.versicherungsNummer)
                }
            }
        }
    }

    private var diagnoseKarte: some View {
        AusweisSektion(titel: "Diagnosen", symbol: "staroflife.fill") {
            ForEach(aktiveDiagnosen) { d in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.bezeichnung).font(.subheadline)
                        if !d.icdCode.isEmpty {
                            Text(d.icdCode).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let datum = d.datum {
                        Text(datum.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
    }

    private var medikamenteKarte: some View {
        AusweisSektion(titel: "Dauermedikation", symbol: "pill.fill") {
            ForEach(aktiveMedikamente) { med in
                HStack(spacing: 10) {
                    Image(systemName: med.typSymbol)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(med.name).font(.subheadline)
                        if !med.dosierung.isEmpty {
                            Text(med.dosierung).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !med.frequenz.isEmpty {
                        Text(med.frequenz).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
    }

    private var arztKarte: some View {
        AusweisSektion(titel: "Rheumatologin / Rheumatologe", symbol: "stethoscope") {
            if let arzt = rheumatologe {
                if !arzt.name.isEmpty {
                    AusweisZeile(label: "Name", wert: arzt.name)
                }
                if !arzt.praxis.isEmpty {
                    AusweisZeile(label: "Praxis", wert: arzt.praxis)
                }
                if !arzt.telefon.isEmpty {
                    AusweisZeile(label: "Telefon", wert: arzt.telefon)
                }
            }
        }
    }

    private var notfallKontaktKarte: some View {
        AusweisSektion(titel: "Notfallkontakt", symbol: "phone.fill") {
            if let kontakt = ersterNotfallKontakt {
                if !kontakt.name.isEmpty {
                    AusweisZeile(label: "Name", wert: kontakt.name)
                }
                if !kontakt.beziehung.isEmpty {
                    AusweisZeile(label: "Beziehung", wert: kontakt.beziehung)
                }
                if !kontakt.phone.isEmpty {
                    AusweisZeile(label: "Telefon", wert: kontakt.phone)
                }
            }
        }
    }

    // MARK: - Teilen

    private var ausweisText: String {
        var zeilen: [String] = ["=== MEDIZINISCHER NOTFALLAUSWEIS ===", ""]

        if let profil {
            zeilen.append("PERSÖNLICHE DATEN")
            let name = "\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { zeilen.append("Name: \(name)") }
            if let geb = profil.geburtsdatum {
                zeilen.append("Geburtsdatum: \(geb.formatted(date: .long, time: .omitted))")
            }
            if !profil.blutgruppe.isEmpty { zeilen.append("Blutgruppe: \(profil.blutgruppe)") }
            if !profil.versicherung.isEmpty { zeilen.append("Versicherung: \(profil.versicherung)") }
            if !profil.versicherungsNummer.isEmpty { zeilen.append("Vers.-Nr.: \(profil.versicherungsNummer)") }
            zeilen.append("")
        }

        if !aktiveDiagnosen.isEmpty {
            zeilen.append("DIAGNOSEN")
            for d in aktiveDiagnosen {
                var zeile = d.bezeichnung
                if !d.icdCode.isEmpty { zeile += " (\(d.icdCode))" }
                zeilen.append("• \(zeile)")
            }
            zeilen.append("")
        }

        if !aktiveMedikamente.isEmpty {
            zeilen.append("DAUERMEDIKATION")
            for med in aktiveMedikamente {
                var zeile = med.name
                if !med.dosierung.isEmpty { zeile += " \(med.dosierung)" }
                if !med.frequenz.isEmpty { zeile += ", \(med.frequenz)" }
                zeilen.append("• \(zeile)")
            }
            zeilen.append("")
        }

        if zeigeImmunWarnung {
            zeilen.append("⚠ IMMUNSUPPRESSIVA – KEIN LEBEND-ATTENUIERTER IMPFSTOFF")
            zeilen.append("")
        }

        if let arzt = rheumatologe {
            zeilen.append("RHEUMATOLOGE / RHEUMATOLOGIN")
            if !arzt.name.isEmpty { zeilen.append("Name: \(arzt.name)") }
            if !arzt.praxis.isEmpty { zeilen.append("Praxis: \(arzt.praxis)") }
            if !arzt.telefon.isEmpty { zeilen.append("Tel.: \(arzt.telefon)") }
            zeilen.append("")
        }

        if let kontakt = ersterNotfallKontakt {
            zeilen.append("NOTFALLKONTAKT")
            if !kontakt.name.isEmpty { zeilen.append("Name: \(kontakt.name)") }
            if !kontakt.beziehung.isEmpty { zeilen.append("Beziehung: \(kontakt.beziehung)") }
            if !kontakt.phone.isEmpty { zeilen.append("Tel.: \(kontakt.phone)") }
        }

        return zeilen.joined(separator: "\n")
    }
}

// MARK: - Hilfskomponenten

private struct AusweisSektion<Content: View>: View {
    let titel: String
    let symbol: String
    @ViewBuilder let inhalt: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(.blue)
                Text(titel)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
            Divider()
            inhalt()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AusweisZeile: View {
    let label: String
    let wert: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(wert)
                .font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
