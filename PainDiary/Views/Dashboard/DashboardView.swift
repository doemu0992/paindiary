import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @Query private var medikamente: [Dauermedikation]
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var midasBewertungen: [MIDASBewertung]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var einnahmeLogs: [EinnahmeLog]
    @State private var viewModel = DashboardViewModel()
    @State private var exportURL: URL? = nil
    @State private var pdfVorschauAnzeigen = false
    @State private var exportOptionsAnzeigen = false
    @State private var exportOptionen = ExportOptionen()
    @State private var istAmExportieren = false
    @State private var tagesstart = Calendar.current.startOfDay(for: Date())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                begrüssungsHeader

                abschnittTitel("Heute")
                heuteKarte
                if profile.first?.zyklusTrackingAktiv == true { zyklusKarte }
                if !medikamente.filter(\.aktiv).isEmpty { medikamentenKarte }
                wellnessKarte

                abschnittTitel("Verlauf")
                schmerzVerlaufChart

                abschnittTitel("Zuletzt")
                letzteEintraege
                schnellLinks
            }
            .padding()
        }
        .navigationTitle("Übersicht")
        .onChange(of: eintraege) { _, neu in viewModel.eintraege = neu }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { tagesstart = Calendar.current.startOfDay(for: Date()) }
        }
        .onAppear { viewModel.eintraege = eintraege }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if istAmExportieren {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Button { exportOptionsAnzeigen = true } label: {
                            Label("Exportieren", systemImage: "square.and.arrow.up")
                        }
                        .disabled(eintraege.isEmpty)
                    }
                }
            }
        }
#if os(iOS)
        .sheet(isPresented: $exportOptionsAnzeigen) {
            ExportOptionsSheet(
                optionen: $exportOptionen,
                hatZyklusDaten: !zyklusEintraege.isEmpty
            ) {
                exportOptionsAnzeigen = false
                exportierePDF()
            }
        }
        .sheet(isPresented: $pdfVorschauAnzeigen) {
            if let url = exportURL { PDFPreviewView(url: url) }
        }
#endif
    }

    // MARK: - Helpers

    private func abschnittTitel(_ titel: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.indigo)
                .frame(width: 3, height: 18)
            Text(titel).font(.title3.bold())
            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func miniStat(_ label: String, wert: String, farbe: Color) -> some View {
        VStack(spacing: 3) {
            Text(wert)
                .font(.subheadline.bold())
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendVorwoche: Double? {
        let kal = Calendar.current
        let jetzt = Date()
        guard let wocheStart = kal.date(byAdding: .day, value: -7, to: jetzt),
              let vorwocheStart = kal.date(byAdding: .day, value: -14, to: jetzt) else { return nil }
        let dieseWoche = eintraege.filter { $0.datum >= wocheStart }
        let vorwoche = eintraege.filter { $0.datum >= vorwocheStart && $0.datum < wocheStart }
        guard !dieseWoche.isEmpty && !vorwoche.isEmpty else { return nil }
        let a = Double(dieseWoche.map(\.schmerzstaerke).reduce(0, +)) / Double(dieseWoche.count)
        let b = Double(vorwoche.map(\.schmerzstaerke).reduce(0, +)) / Double(vorwoche.count)
        return a - b
    }

    @ViewBuilder
    private var trendBadge: some View {
        if let trend = trendVorwoche {
            let symbol: String = trend > 0.2 ? "arrow.up" : trend < -0.2 ? "arrow.down" : "minus"
            let farbe: Color  = trend > 0.2 ? .red    : trend < -0.2 ? .green    : .secondary
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.caption.bold())
                Text(String(format: "%+.1f", trend)).font(.caption.bold())
            }
            .foregroundStyle(farbe)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(farbe.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - Header

    private var begrüssungsHeader: some View {
        let stunde = Calendar.current.component(.hour, from: Date())
        let grussBase = stunde < 12 ? "Guten Morgen" : stunde < 18 ? "Guten Tag" : "Guten Abend"
        let vorname = profile.first?.vorname.trimmingCharacters(in: .whitespaces) ?? ""
        let gruss = vorname.isEmpty ? grussBase : "\(grussBase), \(vorname)"
        let df = DateFormatter()
        df.dateFormat = "EEEE, d. MMMM"
        df.locale = Locale(identifier: "de_CH")
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(gruss).font(.title2.bold())
                Text(df.string(from: Date())).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Heute-Karte (ersetzt 2×2 Grid)

    private var heuteKarte: some View {
        let avg = viewModel.durchschnittsSchmerz
        let farbe = SchmerzBadge.farbe(fuer: Int(avg.rounded()))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ø Schmerzstärke")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", avg))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(farbe)
                        Text("/ 10")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    trendBadge
                    Text("vs. Vorwoche")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 0) {
                miniStat("Diese Woche", wert: String(format: "%.1f", viewModel.wochenschmerz), farbe: .blue)
                Divider().frame(height: 36)
                miniStat("Einträge", wert: "\(eintraege.count)", farbe: .indigo)
                Divider().frame(height: 36)
                miniStat("Top Auslöser", wert: viewModel.haeufigsterAusloeser ?? "–", farbe: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Karten

    private var medikamentenKarte: some View {
        let aktive = medikamente.filter(\.aktiv)
        let notif = NotificationManager.shared
        let heuteLogs = einnahmeLogs.filter { $0.datum >= tagesstart && $0.eingenommen }

        return NavigationLink(destination: MedikamenteView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Medikamente heute", systemImage: "pill.fill")
                        .font(.headline).foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                ForEach(aktive.prefix(3)) { med in
                    let erwartet = notif.anzahlDosen(med.frequenz)
                    let eingenommen = heuteLogs.filter { $0.medikamentName == med.name && $0.dosierung == med.dosierung }.count
                    let fertig = erwartet > 0 ? eingenommen >= erwartet : eingenommen > 0
                    HStack(spacing: 10) {
                        Image(systemName: fertig ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(fertig ? .green : .secondary).font(.body)
                        Text(med.name).font(.subheadline)
                            .foregroundStyle(fertig ? .secondary : .primary)
                        if !med.dosierung.isEmpty {
                            Text(med.dosierung).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if erwartet > 1 {
                            Text("\(eingenommen)/\(erwartet)").font(.caption)
                                .foregroundStyle(fertig ? .green : .secondary)
                        } else if erwartet == 0 && eingenommen > 0 {
                            Text("\(eingenommen)×").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if aktive.count > 3 {
                    Text("+ \(aktive.count - 3) weitere").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var wellnessKarte: some View {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let wasserMl = UserDefaults.standard.integer(forKey: "wasserMl_\(df.string(from: Date()))")
        let wasserZiel = { let z = UserDefaults.standard.integer(forKey: "wasserZielMl"); return z > 0 ? z : 2000 }()
        let fortschritt = min(Double(wasserMl) / Double(wasserZiel), 1.0)

        return NavigationLink(destination: WellnessView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Wohlbefinden", systemImage: "heart.text.square.fill")
                        .font(.headline).foregroundStyle(.pink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(Color.teal.opacity(0.2), lineWidth: 5).frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: fortschritt)
                                .stroke(Color.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)
                            Image(systemName: "drop.fill").font(.caption).foregroundStyle(.teal)
                        }
                        Text("\(wasserMl) ml").font(.caption.bold())
                        Text("Wasser").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 56)

                    VStack(spacing: 6) {
                        Image(systemName: fortschritt >= 1 ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.title2).foregroundStyle(fortschritt >= 1 ? .green : .secondary)
                        Text(fortschritt >= 1 ? "Ziel erreicht" : String(format: "%.0f%%", fortschritt * 100))
                            .font(.caption.bold()).foregroundStyle(fortschritt >= 1 ? .green : .secondary)
                        Text("Tagesziel").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var zyklusKarte: some View {
        let analyse = ZyklusRechner.analyse(eintraege: Array(zyklusEintraege))
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())

        let tageZylus: String = {
            if let t = analyse.aktuellerZyklustag { return "Tag \(t)" }
            return "–"
        }()
        let tageZuPeriode: String = {
            guard let np = analyse.naechstePeriodeStart else { return "–" }
            let diff = kal.dateComponents([.day], from: heute, to: np).day ?? 0
            return diff <= 0 ? "Heute" : "in \(diff) Tagen"
        }()
        let fruchtbarFenster: String = {
            let sorted = analyse.fruchtbareTageSet.filter { $0 >= heute }.sorted()
            guard let first = sorted.first else { return "–" }
            var last = first
            for tag in sorted.dropFirst() {
                if (kal.dateComponents([.day], from: last, to: tag).day ?? 99) <= 1 { last = tag } else { break }
            }
            let fmt = DateFormatter(); fmt.dateFormat = "d. MMM"
            if kal.isDate(first, inSameDayAs: last) { return fmt.string(from: first) }
            return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        }()

        return NavigationLink(destination: ZyklusView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Zyklus-Tracker", systemImage: "drop.circle.fill")
                        .font(.headline).foregroundStyle(.pink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                HStack(spacing: 0) {
                    ZyklusStatSpalte(titel: "Zyklustag", wert: tageZylus, farbe: .pink)
                    Divider().frame(height: 36)
                    ZyklusStatSpalte(titel: "Nächste Periode", wert: tageZuPeriode, farbe: .red)
                    Divider().frame(height: 36)
                    ZyklusStatSpalte(titel: "Fruchtbares Fenster", wert: fruchtbarFenster, farbe: .teal)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var schnellLinks: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: MIDASView()) {
                HStack {
                    Image(systemName: "brain.head.profile").foregroundStyle(.purple)
                    Text("MIDAS-Score").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: KorrelationsView()) {
                HStack {
                    Image(systemName: "chart.xyaxis.line").foregroundStyle(.teal)
                    Text("Analysen").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var schmerzVerlaufChart: some View {
        SchmerzVerlaufKarte(eintraege: Array(eintraege))
    }

    private var letzteEintraege: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte Einträge").font(.headline)

            if eintraege.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("Noch keine Einträge").font(.subheadline.bold())
                    Text("Tippe auf + um deinen ersten Schmerzeintrag zu erfassen.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(eintraege.prefix(5)) { eintrag in
                    NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                        HStack(spacing: 12) {
                            SchmerzBadge(staerke: eintrag.schmerzstaerke)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(eintrag.koerperstelle.isEmpty ? "Körperstelle unbekannt" : eintrag.koerperstelle)
                                    .font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                                Group {
                                    if Calendar.current.isDateInToday(eintrag.datum) {
                                        Text(eintrag.datum, style: .relative)
                                    } else if Calendar.current.isDateInYesterday(eintrag.datum) {
                                        Text("Gestern")
                                    } else {
                                        Text(eintrag.datum, style: .date)
                                    }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    if eintrag.id != eintraege.prefix(5).last?.id { Divider() }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - PDF

    private func exportierePDF() {
#if os(iOS)
        istAmExportieren = true
        PDFExportService.shared.erstellePDFAsync(
            eintraege: Array(eintraege),
            medikamente: Array(medikamente),
            einnahmeLogs: Array(einnahmeLogs),
            midasBewertungen: Array(midasBewertungen),
            zyklusEintraege: Array(zyklusEintraege),
            profil: profile.first,
            optionen: exportOptionen
        ) { @MainActor url in
            istAmExportieren = false
            if let url { exportURL = url; pdfVorschauAnzeigen = true }
        }
#endif
    }
}

#if os(iOS)
private struct ExportOptionsSheet: View {
    @Binding var optionen: ExportOptionen
    @Environment(\.dismiss) private var dismiss
    let hatZyklusDaten: Bool
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $optionen.zeitraum) {
                        ForEach(ExportZeitraum.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section("Abschnitte") {
                    Toggle("Zusammenfassung", isOn: $optionen.mitZusammenfassung)
                    Toggle("Medikamente", isOn: $optionen.mitMedikamente)
                    Toggle("Medikamenten-Dossier", isOn: $optionen.mitMedikamentDossier)
                    if hatZyklusDaten { Toggle("Zyklus", isOn: $optionen.mitZyklus) }
                    Toggle("Alle Einträge", isOn: $optionen.mitEintraege)
                }
            }
            .navigationTitle("PDF exportieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Exportieren", action: onExport) }
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
#endif

private struct ZyklusStatSpalte: View {
    let titel: String; let wert: String; let farbe: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(wert).font(.subheadline.bold()).foregroundStyle(farbe)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(titel).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
