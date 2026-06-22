import SwiftUI
import SwiftData

struct SchlafView: View {
    let nächte: [SleepNightSummary]
    @State private var zeigeAnalyse = false

    private var avg30Qualitaet: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let gefiltert = nächte.filter { $0.date >= cutoff }
        guard !gefiltert.isEmpty else { return "–" }
        let avg = gefiltert.map(\.qualitaet).reduce(0, +) / Double(gefiltert.count)
        return String(format: "%.0f", avg)
    }

    private var avgDauer30: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let gefiltert = nächte.filter { $0.date >= cutoff }
        guard !gefiltert.isEmpty else { return "–" }
        let avg = gefiltert.map(\.dauerStunden).reduce(0, +) / Double(gefiltert.count)
        return String(format: "%.1f h", avg)
    }

    private var anzahl30: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return nächte.filter { $0.date >= cutoff }.count
    }

    var body: some View {
        List {
            statistikSektion

            if nächte.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.indigo.opacity(0.4))
                        Text("Noch keine Schlafdaten")
                            .font(.headline)
                        Text("Starte eine Schlafaufzeichnung in SleepBuddy. Die Daten erscheinen hier automatisch nach der nächsten Nacht.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Schlafnächte") {
                    ForEach(nächte) { nacht in
                        SchlafNachtZeile(nacht: nacht)
                    }
                }
            }
        }
        .navigationTitle("Schlaf")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !nächte.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button { zeigeAnalyse = true } label: {
                        Label("Analyse", systemImage: "chart.bar.xaxis.ascending")
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeAnalyse) {
            SchlafAnalyseView(nächte: nächte)
        }
    }

    private var statistikSektion: some View {
        Section {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("30-Tage-Überblick", systemImage: "moon.stars.fill")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                    Divider()
                    HStack(spacing: 0) {
                        statPill(avg30Qualitaet, label: "Ø Qualität", farbe: avg30Qualitaet == "–" ? .secondary : .indigo)
                        Divider().frame(height: 40)
                        statPill(avgDauer30, label: "Ø Dauer", farbe: .secondary)
                        Divider().frame(height: 40)
                        statPill("\(anzahl30)", label: "Nächte", farbe: .secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

                if !nächte.isEmpty {
                    Button { zeigeAnalyse = true } label: {
                        Label("Schlaf-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.indigo, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nacht-Zeile

struct SchlafNachtZeile: View {
    let nacht: SleepNightSummary

    private var qualFarbe: Color {
        if nacht.qualitaet >= 70 { return .green }
        if nacht.qualitaet >= 45 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(qualFarbe.opacity(0.15))
                    .frame(width: 42, height: 42)
                Text(String(format: "%.0f", nacht.qualitaet))
                    .font(.subheadline.bold())
                    .foregroundStyle(qualFarbe)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(nacht.date, style: .date)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text(String(format: "%.1f h", nacht.dauerStunden))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    phaseBadge("Tief \(Int(nacht.tiefPct * 100))%", farbe: .indigo)
                    phaseBadge("REM \(Int(nacht.remPct * 100))%", farbe: .purple)
                }
            }

            Spacer()
        }
    }

    private func phaseBadge(_ text: String, farbe: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(farbe)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(farbe.opacity(0.12), in: Capsule())
    }
}
