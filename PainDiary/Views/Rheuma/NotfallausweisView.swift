import SwiftUI
import SwiftData

struct NotfallausweisView: View {
    @Query(sort: \Diagnose.bezeichnung) private var diagnosen: [Diagnose]
    @Query(sort: \Allergie.schwere) private var allergien: [Allergie]
    @Query private var medikamente: [Dauermedikation]
    @Query private var profile: [Benutzerprofil]

    @State private var pdfURL: URL? = nil
    @State private var zeigePDFVorschau = false
    @State private var istAmExportieren = false

    private var profil: Benutzerprofil? { profile.first }
    private var aerzte: [ArztKontakt] { profil?.aerzte ?? [] }
    private var notfallKontakte: [NotfallKontakt] { profil?.notfallkontakte ?? [] }
    private var aktiveDiagnosen: [Diagnose] { diagnosen.filter { $0.aktiv } }
    private var aktiveMedikamente: [Dauermedikation] { medikamente.filter { $0.aktiv } }

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

                if !allergien.isEmpty {
                    allergienKarte
                }

                if !aktiveMedikamente.isEmpty {
                    medikamenteKarte
                }

                if !aerzte.isEmpty {
                    arztKarte
                }

                if !notfallKontakte.isEmpty {
                    notfallKontaktKarte
                }
            }
            .padding()
        }
        .navigationTitle("Notfallausweis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if istAmExportieren {
                    ProgressView()
                } else {
                    Button {
                        exportierenAlsPDF()
                    } label: {
                        Label("PDF", systemImage: "doc.fill")
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
#if os(iOS)
        .sheet(isPresented: $zeigePDFVorschau) {
            if let url = pdfURL {
                PDFPreviewView(url: url)
            }
        }
#endif
    }

    // MARK: - PDF Export

    private func exportierenAlsPDF() {
        istAmExportieren = true
        PDFExportService.shared.erstelleNotfallausweisAsync(
            profil: profil,
            diagnosen: diagnosen,
            allergien: Array(allergien),
            medikamente: Array(medikamente),
            istImmunSuppr: zeigeImmunWarnung
        ) { url in
            istAmExportieren = false
            if let url {
                pdfURL = url
                zeigePDFVorschau = true
            }
        }
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
                if let profil {
                    Text("\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces))
                        .font(.title3.bold())
                    if let geb = profil.geburtsdatum {
                        let alter = Calendar.current.dateComponents([.year], from: geb, to: Date()).year ?? 0
                        Text("\(alter) Jahre")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
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
        AusweisSektion(titel: "Diagnosen", symbol: "cross.case.fill") {
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

    private var allergienKarte: some View {
        AusweisSektion(titel: "Allergien & Unverträglichkeiten", symbol: "allergens") {
            ForEach(allergien) { a in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.substanz).font(.subheadline)
                        if !a.reaktion.isEmpty {
                            Text(a.reaktion).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    AllergieSchwereBadge(schwere: a.schwere)
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
        AusweisSektion(titel: "Behandelnde Ärzte", symbol: "stethoscope") {
            ForEach(aerzte) { arzt in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(arzt.name.isEmpty ? arzt.praxis : arzt.name)
                            .font(.subheadline.bold())
                        if arzt.istHausarzt {
                            Text("Hausarzt").font(.caption2).foregroundStyle(.blue)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12)).clipShape(Capsule())
                        }
                        Spacer()
                        if !arzt.fachgebiet.isEmpty {
                            Text(arzt.fachgebiet).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !arzt.name.isEmpty && !arzt.praxis.isEmpty {
                        Text(arzt.praxis).font(.caption).foregroundStyle(.secondary)
                    }
                    if !arzt.telefon.isEmpty {
                        Label(arzt.telefon, systemImage: "phone")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                if arzt.id != aerzte.last?.id {
                    Divider()
                }
            }
        }
    }

    private var notfallKontaktKarte: some View {
        AusweisSektion(titel: "Notfallkontakte", symbol: "phone.fill") {
            ForEach(notfallKontakte) { kontakt in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kontakt.name).font(.subheadline.bold())
                        if !kontakt.beziehung.isEmpty {
                            Text(kontakt.beziehung).font(.caption).foregroundStyle(.secondary)
                        }
                        if !kontakt.phone.isEmpty {
                            Label(kontakt.phone, systemImage: "phone")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
                if kontakt.id != notfallKontakte.last?.id {
                    Divider()
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

        if !allergien.isEmpty {
            zeilen.append("ALLERGIEN & UNVERTRÄGLICHKEITEN")
            for a in allergien {
                var zeile = a.substanz
                if !a.reaktion.isEmpty { zeile += ": \(a.reaktion)" }
                zeile += " [\(a.schwere)]"
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

        if !aerzte.isEmpty {
            zeilen.append("BEHANDELNDE ÄRZTE")
            for arzt in aerzte {
                let label = arzt.istHausarzt ? "Hausarzt" : arzt.fachgebiet
                let name = arzt.name.isEmpty ? arzt.praxis : arzt.name
                var zeile = name
                if !label.isEmpty { zeile += " (\(label))" }
                if !arzt.telefon.isEmpty { zeile += " – Tel. \(arzt.telefon)" }
                zeilen.append("• \(zeile)")
            }
            zeilen.append("")
        }

        if !notfallKontakte.isEmpty {
            zeilen.append("NOTFALLKONTAKTE")
            for kontakt in notfallKontakte {
                var zeile = kontakt.name
                if !kontakt.beziehung.isEmpty { zeile += " (\(kontakt.beziehung))" }
                if !kontakt.phone.isEmpty { zeile += " – Tel. \(kontakt.phone)" }
                zeilen.append("• \(zeile)")
            }
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
