import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @State private var viewModel = DashboardViewModel()
    @State private var exportURL: URL? = nil
    @State private var exportTeilen = false

    private var patientenName: String {
        guard let p = profile.first else { return "" }
        return "\(p.vorname) \(p.nachname)".trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statistikKarten
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
                Button {
                    exportierePDF()
                } label: {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                .disabled(eintraege.isEmpty)
            }
        }
#if os(iOS)
        .sheet(isPresented: $exportTeilen) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
#endif
    }

    private func exportierePDF() {
#if os(iOS)
        if let url = PDFExportService.shared.erstellePDF(eintraege: Array(eintraege), patientenName: patientenName) {
            exportURL = url
            exportTeilen = true
        }
#endif
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
