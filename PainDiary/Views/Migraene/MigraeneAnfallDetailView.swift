import SwiftUI

struct MigraeneAnfallDetailView: View {
    let anfall: MigraeneEintrag
    @State private var bearbeiten = false
    @State private var zeigePostdrom = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroKarte

                if !anfall.seite.isEmpty || anfall.dauer > 0 || anfall.endZeit != nil {
                    anfallKarte
                }

                if !anfall.prodromsymptome.isEmpty {
                    chipKarte("Prodromsymptome", symbol: "clock.arrow.circlepath",
                              farbe: .indigo, chips: anfall.prodromListe)
                }

                if anfall.hatAura || !anfall.charakter.isEmpty {
                    charakterKarte
                }

                if !anfall.begleitsymptome.isEmpty {
                    chipKarte("Begleitsymptome", symbol: "list.bullet.medical",
                              farbe: .red, chips: anfall.begleitsymptomeListe)
                }

                if !anfall.ausloeser.isEmpty {
                    chipKarte("Auslöser", symbol: "exclamationmark.triangle.fill",
                              farbe: .orange, chips: anfall.ausloeserListe)
                }

                if !anfall.akutmedikament.isEmpty {
                    medikamentKarte
                }

                postdromKarte

                wetterKarte

                if !anfall.zyklusPhase.isEmpty {
                    zyklusKarte
                }

                if !anfall.notizen.isEmpty {
                    textKarte("Notizen", symbol: "note.text", farbe: .secondary, text: anfall.notizen)
                }
            }
            .padding()
        }
        .navigationTitle(anfall.kopfschmerzTyp.isEmpty ? "Migräne" : anfall.kopfschmerzTyp)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") { bearbeiten = true }
            }
        }
        .sheet(isPresented: $bearbeiten) {
            MigraeneAnfallForm(anfall: anfall)
        }
        .sheet(isPresented: $zeigePostdrom) {
            PostdromErfassungView(anfall: anfall)
        }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        let farbe = staerkeFarbe
        return VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(anfall.kopfschmerzTyp.isEmpty ? "Migräne-Anfall" : anfall.kopfschmerzTyp)
                        .font(.title3.bold())
                    HStack(spacing: 4) {
                        Text(anfall.datum, style: .date)
                        Text("·").foregroundStyle(.secondary)
                        Text(anfall.datum, style: .time)
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                    if anfall.hatAura {
                        Label("Mit Aura", systemImage: "eye.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.purple, in: Capsule())
                    }
                }
                Spacer()
                ZStack {
                    Circle().fill(farbe.opacity(0.15)).frame(width: 64, height: 64)
                    VStack(spacing: 1) {
                        Text("\(anfall.staerke)")
                            .font(.largeTitle.bold()).foregroundStyle(farbe)
                        Text("/10").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [farbe.opacity(0.7), farbe],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(anfall.staerke) / 10, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Schmerzstärke").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(anfall.staerke) / 10").font(.caption.bold()).foregroundStyle(farbe)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Anfall

    private var anfallKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Anfall", systemImage: "brain.head.profile")
                .font(.headline).foregroundStyle(.purple)
            Divider()
            if !anfall.seite.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lokalisation").font(.subheadline).foregroundStyle(.secondary)
                    chipReihe(anfall.seite.components(separatedBy: ", ").filter { !$0.isEmpty }, farbe: .purple)
                }
            }
            if anfall.dauer > 0 {
                zeile("Dauer", wert: anfall.dauerText)
            }
            if let end = anfall.endZeit {
                zeile("Endzeit", wert: end.formatted(date: .omitted, time: .shortened))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Charakter

    private var charakterKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Charakter", systemImage: "waveform.path.ecg")
                .font(.headline).foregroundStyle(.purple)
            Divider()
            if anfall.hatAura {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill").foregroundStyle(.purple)
                    Text("Aura vorhanden").font(.subheadline)
                }
            }
            if !anfall.charakterListe.isEmpty {
                chipReihe(anfall.charakterListe, farbe: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Medikament

    private var medikamentKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Akutmedikament", systemImage: "pill.fill")
                .font(.headline).foregroundStyle(.blue)
            Divider()
            zeile("Medikament", wert: anfall.akutmedikament)
            if !anfall.medikamentWirksam.isEmpty {
                zeile("Wirksamkeit", wert: anfall.medikamentWirksam)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Wetter

    @ViewBuilder
    private var wetterKarte: some View {
        if let code = anfall.wetterCode {
            VStack(alignment: .leading, spacing: 12) {
                Label("Wetter", systemImage: "cloud.sun.fill")
                    .font(.headline).foregroundStyle(.blue)
                Divider()
                HStack(spacing: 14) {
                    Image(systemName: WetterSnapshot.symbolFuerCode(code))
                        .font(.largeTitle).foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WetterSnapshot.beschreibungFuerCode(code))
                            .font(.subheadline.bold())
                        if let temp = anfall.wetterTemperatur {
                            Text(String(format: "%.0f°C", temp))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let wind = anfall.wetterWind, wind > 0 {
                        Label(String(format: "%.0f km/h", wind), systemImage: "wind")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
    }

    // MARK: - Zyklus

    private var zyklusKarte: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill").foregroundStyle(.pink).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Zyklusphase").font(.subheadline.bold())
                Text(anfall.zyklusPhase).font(.caption).foregroundStyle(.pink)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Postdrom

    private var postdromKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Postdromsymptome", systemImage: "arrow.clockwise.circle.fill")
                .font(.headline).foregroundStyle(.teal)
            Divider()
            if !anfall.postdrom.isEmpty {
                chipReihe(anfall.postdromListe, farbe: .teal)
            } else {
                let erinnerungsZeit = anfall.datum.addingTimeInterval(24 * 3600)
                VStack(alignment: .leading, spacing: 10) {
                    if erinnerungsZeit > Date() {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill").foregroundStyle(.teal).font(.caption)
                            Text("Push-Erinnerung um \(erinnerungsZeit.formatted(date: .omitted, time: .shortened)) Uhr")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Noch nicht erfasst")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        zeigePostdrom = true
                    } label: {
                        Label("Jetzt erfassen", systemImage: "plus.circle")
                            .font(.subheadline.bold())
                            .foregroundStyle(.teal)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func chipKarte(_ titel: String, symbol: String, farbe: Color, chips: [String]) -> some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label(titel, systemImage: symbol)
                    .font(.headline).foregroundStyle(farbe)
                Divider()
                chipReihe(chips, farbe: farbe)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
    }

    private func textKarte(_ titel: String, symbol: String, farbe: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(titel, systemImage: symbol)
                .font(.headline).foregroundStyle(farbe)
            Divider()
            Text(text).font(.body).foregroundStyle(.primary.opacity(0.85))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func chipReihe(_ items: [String], farbe: Color) -> some View {
        FlowLayout(items) { item in
            Text(item)
                .font(.caption.bold())
                .foregroundStyle(farbe)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(farbe.opacity(0.12), in: Capsule())
        }
    }

    private func zeile(_ label: String, wert: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(wert).font(.subheadline.bold()).multilineTextAlignment(.trailing)
        }
    }

    private var staerkeFarbe: Color {
        switch anfall.staerke {
        case 1...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}
