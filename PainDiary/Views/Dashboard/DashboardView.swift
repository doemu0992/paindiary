import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @Query private var medikamente: [Dauermedikation]
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var midasBewertungen: [MIDASBewertung]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    @State private var viewModel = DashboardViewModel()
    @State private var exportURL: URL? = nil
    @State private var exportTeilen = false
    @State private var exportOptionsAnzeigen = false
    @State private var exportOptionen = ExportOptionen()
    @State private var istAmExportieren = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statistikKarten
                if !zyklusEintraege.isEmpty { zyklusKarte }
                schnellLinks
                schmerzVerlaufChart
                letzteEintraege
            }
            .padding()
        }
        .navigationTitle("Übersicht")
        .onChange(of: eintraege) { _, neu in viewModel.eintraege = neu }
        .onAppear { viewModel.eintraege = eintraege }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if istAmExportieren {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Button {
                            exportOptionsAnzeigen = true
                        } label: {
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
        .sheet(isPresented: $exportTeilen) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
#endif
    }

    private func exportierePDF() {
#if os(iOS)
        istAmExportieren = true
        PDFExportService.shared.erstellePDFAsync(
            eintraege: Array(eintraege),
            medikamente: Array(medikamente),
            midasBewertungen: Array(midasBewertungen),
            zyklusEintraege: Array(zyklusEintraege),
            profil: profile.first,
            optionen: exportOptionen
        ) { @MainActor url in
            istAmExportieren = false
            if let url {
                exportURL = url
                exportTeilen = true
            }
        }
#endif
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
            let fmt = DateFormatter()
            fmt.dateFormat = "d. MMM"
            if kal.isDate(first, inSameDayAs: last) { return fmt.string(from: first) }
            return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        }()

        return NavigationLink(destination: ZyklusView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Zyklus-Tracker", systemImage: "drop.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.pink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            NavigationLink(destination: KorrelationsView()) {
                HStack {
                    Image(systemName: "chart.xyaxis.line").foregroundStyle(.teal)
                    Text("Korrelationen").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var statistikKarten: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatKarte(titel: "Ø Schmerz", wert: String(format: "%.1f", viewModel.durchschnittsSchmerz), symbol: "waveform.path.ecg", farbe: .orange)
            StatKarte(titel: "Diese Woche", wert: String(format: "%.1f", viewModel.wochenschmerz), symbol: "calendar.badge.clock", farbe: .blue)
            StatKarte(titel: "Einträge", wert: "\(eintraege.count)", symbol: "list.bullet.clipboard", farbe: .green)
            if let ausloeser = viewModel.haeufigsterAusloeser {
                StatKarte(titel: "Top Auslöser", wert: ausloeser, symbol: "exclamationmark.triangle", farbe: .red)
            } else {
                StatKarte(titel: "Top Auslöser", wert: "–", symbol: "exclamationmark.triangle", farbe: .red)
            }
        }
    }

    private var schmerzVerlaufChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schmerzverlauf (7 Tage)")
                .font(.headline)

            if viewModel.letzten7TageEintraege.isEmpty {
                Text("Noch nicht genug Daten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(viewModel.letzten7TageEintraege, id: \.datum) { punkt in
                    LineMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Schmerz", punkt.schmerz)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Schmerz", punkt.schmerz)
                    )
                    .foregroundStyle(Color.orange.opacity(0.15).gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Schmerz", punkt.schmerz)
                    )
                    .foregroundStyle(SchmerzBadge.farbe(fuer: Int(punkt.schmerz)))
                }
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) {
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 160)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var letzteEintraege: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte Einträge")
                .font(.headline)

            if eintraege.isEmpty {
                Text("Noch keine Einträge vorhanden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(eintraege.prefix(5)) { eintrag in
                    NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                        HStack(spacing: 12) {
                            SchmerzBadge(staerke: eintrag.schmerzstaerke)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(eintrag.koerperstelle.isEmpty ? "Körperstelle unbekannt" : eintrag.koerperstelle)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(eintrag.datum, style: .relative)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    if eintrag.id != eintraege.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                        ForEach(ExportZeitraum.allCases, id: \.self) { z in
                            Text(z.rawValue).tag(z)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Abschnitte") {
                    Toggle("Zusammenfassung", isOn: $optionen.mitZusammenfassung)
                    Toggle("Medikamente", isOn: $optionen.mitMedikamente)
                    if hatZyklusDaten {
                        Toggle("Zyklus", isOn: $optionen.mitZyklus)
                    }
                    Toggle("Alle Einträge", isOn: $optionen.mitEintraege)
                }
            }
            .navigationTitle("PDF exportieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Exportieren", action: onExport)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
#endif

private struct ZyklusStatSpalte: View {
    let titel: String
    let wert: String
    let farbe: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(wert)
                .font(.subheadline.bold())
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(titel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatKarte: View {
    let titel: String
    let wert: String
    let symbol: String
    let farbe: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(farbe)
                Spacer()
            }
            Text(wert)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(titel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
