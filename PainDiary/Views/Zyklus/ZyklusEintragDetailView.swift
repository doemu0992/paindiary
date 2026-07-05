import SwiftUI

struct ZyklusEintragDetailView: View {
    let eintrag: ZyklusEintrag
    @State private var zeigeBearbeiten = false

    private var symptomListe: [String] {
        eintrag.symptome.components(separatedBy: ", ").filter { !$0.isEmpty }
    }

    private var hatWeitereDaten: Bool {
        !eintrag.ovulationstest.isEmpty ||
        !eintrag.zervixschleim.isEmpty ||
        eintrag.basaltemperatur > 0 ||
        !eintrag.sexuelleAktivitaet.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroKarte
                if eintrag.istPeriode { periodeKarte }
                if !symptomListe.isEmpty { symptomeKarte }
                if hatWeitereDaten { weitereKarte }
                if !eintrag.notizen.trimmingCharacters(in: .whitespaces).isEmpty { notizenKarte }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Zyklus-Eintrag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeBearbeiten = true } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $zeigeBearbeiten) {
            ZyklusEintragSheet(datum: eintrag.datum, bestehend: eintrag)
        }
    }

    // MARK: - Hero

    // 00:00 = rückwirkend erfasster Tages-Eintrag ohne echte Erfassungszeit
    private var datumText: String {
        let hatUhrzeit = Calendar.current.startOfDay(for: eintrag.datum) != eintrag.datum
        var text = eintrag.datum.formatted(.dateTime.day().month(.wide).year())
        if hatUhrzeit {
            text += " · " + eintrag.datum.formatted(.dateTime.hour().minute())
        }
        return text
    }

    private var heroKarte: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Label("Zyklus", systemImage: "drop.fill")
                    .font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.pink, in: Capsule())
                if eintrag.istPeriode {
                    Label("Periode", systemImage: "drop.fill")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red, in: Capsule())
                }
                Spacer()
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eintrag.istPeriode ? "Periodentag" : "Zyklus-Eintrag")
                        .font(.title2.bold())
                    Text(datumText)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Periode

    private var periodeKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Periode", systemImage: "drop.fill")
                .font(.headline).foregroundStyle(.red)
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stärke").font(.caption).foregroundStyle(.secondary)
                    Text(blutungsflussLabel).font(.subheadline.bold())
                }
                Spacer()
                if eintrag.nurHalberTag {
                    Label("Halber Tag", systemImage: "clock.badge.fill")
                        .font(.caption.bold()).foregroundStyle(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private var blutungsflussLabel: String {
        switch eintrag.blutungsfluss {
        case "schmierblutung": return "Schmierblutung"
        case "leicht":         return "Leicht"
        case "mittel":         return "Mittel"
        case "stark":          return "Stark"
        default:               return eintrag.blutungsfluss
        }
    }

    // MARK: - Symptome

    private var symptomeKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Symptome", systemImage: "heart.text.square.fill")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(symptomListe, id: \.self) { s in
                    Text(s)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.pink)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Weitere Daten

    private var weitereKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weitere Daten", systemImage: "waveform.path.ecg")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            VStack(spacing: 10) {
                ForEach(eintrag.ovulationstestMessungen) { messung in
                    datenZeile(symbol: "circle.dotted",
                               label: messung.zeit.map { "Ovulationstest · \($0.formatted(.dateTime.hour().minute())) Uhr" }
                                   ?? "Ovulationstest",
                               wert: ovulationstestLabel(messung.ergebnis),
                               farbe: ovulationstestFarbe(messung.ergebnis))
                }
                if !eintrag.zervixschleim.isEmpty {
                    datenZeile(symbol: "drop.halffull", label: "Zervixschleim",
                               wert: zervixschleimLabel, farbe: .blue)
                }
                if eintrag.basaltemperatur > 0 {
                    datenZeile(symbol: "thermometer.medium", label: "Basaltemperatur",
                               wert: String(format: "%.1f °C", eintrag.basaltemperatur), farbe: .orange)
                }
                if !eintrag.sexuelleAktivitaet.isEmpty {
                    datenZeile(symbol: "heart.fill", label: "Sexuelle Aktivität",
                               wert: sexAktivLabel, farbe: .pink)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func datenZeile(symbol: String, label: String, wert: String, farbe: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(farbe).frame(width: 20)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(wert).font(.subheadline.bold())
        }
    }

    private func ovulationstestLabel(_ ergebnis: String) -> String {
        switch ergebnis {
        case "positiv": return "Positiv"
        case "negativ": return "Negativ"
        case "unklar":  return "Unklar"
        default:        return ergebnis
        }
    }

    private func ovulationstestFarbe(_ ergebnis: String) -> Color {
        switch ergebnis {
        case "positiv": return .green
        case "negativ": return .secondary
        default:        return .orange
        }
    }

    private var zervixschleimLabel: String {
        switch eintrag.zervixschleim {
        case "trocken":  return "Trocken"
        case "klebrig":  return "Klebrig"
        case "cremig":   return "Cremig"
        case "wässrig":  return "Wässrig"
        case "Eiweiss":  return "Eiweiss"
        default:         return eintrag.zervixschleim
        }
    }

    private var sexAktivLabel: String {
        switch eintrag.sexuelleAktivitaet {
        case "geschützt":    return "Geschützt"
        case "ungeschützt":  return "Ungeschützt"
        default:             return eintrag.sexuelleAktivitaet
        }
    }

    // MARK: - Notizen

    private var notizenKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notizen", systemImage: "note.text")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            Text(eintrag.notizen)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}
