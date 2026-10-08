import SwiftUI

// Gemeinsame Anzeige-Bausteine des Zyklus-Moduls. Sie kennen weder ModelContext noch Speichern/Löschen:
// Eigentümer:in (ZyklusView) und Partner:in (ZyklusPartnerView) nutzen exakt dieselben Karten.
// Aktionen (Erfassen, Eisprung bestätigen) kommen nur über optionale Closures von außen.

/// Tage von heute bis `datum` (negativ = Vergangenheit).
func zyklusTageBis(_ datum: Date) -> Int {
    let kal = Calendar.current
    return kal.dateComponents([.day], from: kal.startOfDay(for: Date()), to: kal.startOfDay(for: datum)).day ?? 0
}

// MARK: - Ring + Legende

struct ZyklusRingKarte: View {
    let analyse: ZyklusAnalyse
    @Binding var auswahl: Int?

    var body: some View { ringKarte(analyse) }

    private func ringKarte(_ analyse: ZyklusAnalyse) -> some View {
        VStack(spacing: 12) {
            ZyklusRingView(analyse: analyse, untertitel: ringUntertitel(analyse), auswahl: $auswahl)
                .frame(maxWidth: 300)
                .padding(.top, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], alignment: .leading, spacing: 6) {
                legendenPunkt(ZyklusFarbe.periode, "Periode")
                legendenPunkt(ZyklusFarbe.follikel, "Follikel")
                legendenPunkt(ZyklusFarbe.fruchtbar, "Fruchtbar")
                legendenPunkt(ZyklusFarbe.eisprung, "Eisprung")
                legendenPunkt(ZyklusFarbe.luteal, "Luteal")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(padding: 0)
    }

    private func legendenPunkt(_ farbe: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(text)
        }
    }

    private func ringUntertitel(_ a: ZyklusAnalyse) -> String {
        switch a.status {
        case .keineAktuellenDaten:
            return "Keine aktuellen Daten"
        case .ueberfaellig(let tage):
            return tage == 1 ? "Periode 1 Tag überfällig" : "Periode \(tage) Tage überfällig"
        case .normal:
            if let ov = a.vorhergesagteOvulation, a.naechstePeriodeStart.map({ ov < $0 }) ?? true {
                let t = zyklusTageBis(ov)
                if t <= 0 { return "Eisprung heute erwartet" }
                if t == 1 { return "Eisprung morgen erwartet" }
                return "Eisprung in ca. \(t) Tagen"
            }
            if let np = a.naechstePeriodeStart {
                let t = zyklusTageBis(np)
                if t <= 0 { return "Periode heute erwartet" }
                return t == 1 ? "Periode morgen erwartet" : "Periode in \(t) Tagen"
            }
            return ""
        }
    }
}

// MARK: - Status (überfällig / keine aktuellen Daten)

struct ZyklusStatusKarte: View {
    let analyse: ZyklusAnalyse

    var body: some View { statusKarte(analyse) }

    private func statusKarte(_ a: ZyklusAnalyse) -> some View {
        let text: String
        switch a.status {
        case .ueberfaellig(let tage):
            text = tage >= 7
                ? "Deine Periode ist seit \(tage) Tagen überfällig. Trage sie ein, sobald sie beginnt – die Prognose passt sich dann an."
                : "Deine Periode ist etwas später als erwartet. Zyklen schwanken natürlicherweise um einige Tage."
        case .keineAktuellenDaten:
            text = "Dein letzter erfasster Zyklusstart liegt über 90 Tage zurück. Für neue Prognosen trage bitte die nächste Periode ein."
        case .normal:
            text = ""
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(text).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18, padding: 0)
    }
}

// MARK: - Prognose (Nächste Periode, Fruchtbares Fenster)

struct ZyklusPrognoseReihe: View {
    let analyse: ZyklusAnalyse
    private var kal: Calendar { Calendar.current }

    var body: some View { prognoseReihe(analyse) }

    private func prognoseReihe(_ a: ZyklusAnalyse) -> some View {
        HStack(alignment: .top, spacing: 12) {
            periodeKarte(a)
            fruchtbarKarte(a)
        }
    }

    private func periodeKarte(_ a: ZyklusAnalyse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NÄCHSTE PERIODE")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if case .ueberfaellig(let tage) = a.status {
                Text("Überfällig").font(.title3.bold()).foregroundStyle(.orange)
                Text(tage == 1 ? "seit 1 Tag" : "seit \(tage) Tagen")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let np = a.naechstePeriodeStart {
                Text(np, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.title3.bold())
                let t = zyklusTageBis(np)
                Text(t <= 0 ? "heute" : "in \(t) \(t == 1 ? "Tag" : "Tagen") · ± \(a.unsicherheitTage) T.")
                    .font(.caption).foregroundStyle(.secondary)
                ZyklusUnsicherheitsBand(spanne: a.unsicherheitTage, farbe: ZyklusFarbe.periode)
                    .padding(.top, 4)
            } else {
                Text("–").font(.title3.bold())
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .glassCard(radius: 20, padding: 0)
        .accessibilityElement(children: .combine)
    }

    private func fruchtbarKarte(_ a: ZyklusAnalyse) -> some View {
        let konf = konfidenz(a)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text("FRUCHTBARES FENSTER")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .lineLimit(2)
                InfoButton(titel: "Fruchtbares Fenster",
                           text: "Die 6 Tage bis einschließlich Eisprungtag (Spermien überleben bis zu 5 Tage, die Eizelle 12–24 Stunden). Die Prognose nutzt – in dieser Reihenfolge – BBT-Anstieg, positiven LH-Test, Schleim-Peak und zuletzt den Kalender (nächste Periode minus persönliche Lutealphase). Kommt die Periode früher oder später, verschiebt sich alles automatisch. Ohne Belege sind hellere Randtage um das Fenster möglich; so breit wie dein typischer Prognosefehler. Keine Verhütungsmethode.")
            }
            if let f = a.naechstesFruchtbaresFenster {
                Text(fensterText(f))
                    .font(.title3.bold())
                    .minimumScaleFactor(0.8).lineLimit(1)
            } else {
                Text("–").font(.title3.bold())
            }
            Text(konf.text)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(konf.farbe.opacity(0.18), in: Capsule())
                .foregroundStyle(konf.farbe)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .glassCard(radius: 20, padding: 0)
    }

    private func fensterText(_ f: ClosedRange<Date>) -> String {
        let von = f.lowerBound, bis = f.upperBound
        if kal.isDate(von, equalTo: bis, toGranularity: .month) {
            let tagVon = von.formatted(.dateTime.day().locale(ZyklusLocale.de))
            return "\(tagVon)–\(bis.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)))"
        }
        return "\(von.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de))) – \(bis.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)))"
    }

    private func konfidenz(_ a: ZyklusAnalyse) -> (text: String, farbe: Color) {
        if a.datenQualitaet == .standardwert { return ("Schätzung", .secondary) }
        if a.eisprungBestaetigt { return ("Bestätigt", .teal) }
        if a.regelmaessigkeit == .unregelmaessig { return ("Konfidenz niedrig", .orange) }
        if a.regelmaessigkeit == .regelmaessig && a.datenQualitaet >= .gut { return ("Konfidenz hoch", .teal) }
        return ("Konfidenz mittel", .orange)
    }
}

// MARK: - Zyklus-Überblick

struct ZyklusUeberblickKarte: View {
    let analyse: ZyklusAnalyse

    var body: some View { statistikKarte(analyse) }

    private func statistikKarte(_ a: ZyklusAnalyse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Zyklus-Überblick", systemImage: "drop.fill")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            HStack(spacing: 0) {
                statPill(a.aktuellerZyklustag.map { "Tag \($0)" } ?? "–", label: "Zyklustag",
                         farbe: a.aktuellerZyklustag != nil ? .pink : .secondary)
                Divider().frame(height: 40)
                statPill(a.gueltigeZyklen > 0 ? "\(Int(a.medianZykluslaenge.rounded())) T" : "–",
                         label: "Ø Zyklus (Median)", farbe: .pink)
                Divider().frame(height: 40)
                statPill("\(Int(a.adaptiertePeriodendauer.rounded())) T",
                         label: "Ø Periode", farbe: ZyklusFarbe.periode)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 0)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tageskarte (Zyklustag, Phase, erfasste Werte)

/// Detailkarte zu einem Kalendertag. Ohne `onBearbeiten`/`onEisprung` rein lesend.
struct ZyklusTagesKarte: View {
    let tag: Date
    let analyse: ZyklusAnalyse
    let proTag: [Date: ZyklusTagesSicht]
    /// Prognosen (Periode erwartet, fruchtbar, Eisprung) anzeigen; `false` bei pausierten Prognosen.
    let prognosen: Bool
    var onBearbeiten: ((Date) -> Void)? = nil
    var onEisprung: ((Date) -> Void)? = nil
    private var kal: Calendar { Calendar.current }

    var body: some View { karte }

    private var karte: some View {
        let start = kal.startOfDay(for: tag)
        let heute = kal.startOfDay(for: Date())
        let eintrag = proTag[start]
        let zustand = ZyklusRechner.tagZustand(datum: start, analyse: analyse, kalender: kal)
        let prognosenAn = prognosen

        // Phase nur innerhalb des bekannten Zyklus — für Tage nach der erwarteten nächsten Periode wäre sie falsch.
        let imBekanntenZyklus = start <= heute || (analyse.naechstePeriodeStart.map { start < $0 } ?? false)
        let phase: ZyklusRechner.Zyklusphase? = imBekanntenZyklus
            ? ZyklusRechner.phase(for: start, analyse: analyse, kalender: kal) : nil
        let zyklusTag: Int? = phase == nil ? nil : analyse.zyklusStarts.last(where: { $0 <= start })
            .map { (kal.dateComponents([.day], from: $0, to: start).day ?? 0) + 1 }

        var badges: [(String, Color)] = []
        if zustand.periode {
            let fluss = eintrag?.fluss ?? .keine
            badges.append((fluss == .keine ? "Periode" : "Periode · \(fluss.titel)", ZyklusFarbe.periode))
        }
        if prognosenAn && zustand.vorhergesagtePeriode { badges.append(("Periode erwartet", ZyklusFarbe.periode)) }
        if prognosenAn && zustand.ovulation {
            let q = analyse.zyklen.first(where: { $0.eisprung.map { kal.isDate($0, inSameDayAs: start) } ?? false })?.eisprungQuelle
            let zusatz = q.map { $0.istBestaetigt ? " · bestätigt" : ($0 == .kalender ? " · geschätzt" : " · \($0.titel)") } ?? ""
            badges.append(("Eisprung\(zusatz)", ZyklusFarbe.eisprung))
        }
        if prognosenAn && zustand.fruchtbar { badges.append(("Fruchtbar", ZyklusFarbe.fruchtbar)) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(start, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.bold())
                    if let n = zyklusTag, let p = phase {
                        Text("Zyklustag \(n) · \(p.rawValue)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ZyklusFarbe.farbe(p))
                    } else {
                        Text(start > heute ? "Prognose" : "Außerhalb eines Zyklus")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let onBearbeiten {
                    Button { onBearbeiten(start) } label: {
                        Text(eintrag == nil ? "Erfassen" : "Bearbeiten")
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.pink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let onEisprung, start <= heute && (zustand.ovulation || zustand.fruchtbar) {
                let bestaetigt = eintrag?.eisprungBestaetigt ?? false
                Button { onEisprung(start) } label: {
                    Label(bestaetigt ? "Eisprung-Bestätigung entfernen" : "Eisprung an diesem Tag bestätigen",
                          systemImage: bestaetigt ? "xmark.circle" : "checkmark.seal.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(ZyklusFarbe.eisprung.opacity(0.18), in: Capsule())
                        .foregroundStyle(ZyklusFarbe.eisprung)
                }
                .buttonStyle(.plain)
            }

            if onEisprung == nil, eintrag?.eisprungBestaetigt == true {
                Label("Eisprung bestätigt", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(ZyklusFarbe.eisprung.opacity(0.18), in: Capsule())
                    .foregroundStyle(ZyklusFarbe.eisprung)
            }

            if !badges.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, b in
                        Text(b.0)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(b.1.opacity(0.18), in: Capsule())
                            .foregroundStyle(b.1)
                    }
                }
            }

            if let e = eintrag {
                VStack(alignment: .leading, spacing: 3) {
                    if e.schleim != .keine { Text("Zervixschleim: \(e.schleim.titel)") }
                    if e.lhTest != .keine { Text("Ovulationstest: \(e.lhTest.titel)") }
                    if e.basaltemperatur > 0 { Text("Basaltemperatur: \(String(format: "%.2f", e.basaltemperatur)) °C") }
                    if !e.symptome.isEmpty { Text("Symptome: \(ListenFeld.parse(e.symptome).joined(separator: ", "))") }
                    if e.sexAktivitaet != .keine { Text("Sexuelle Aktivität: \(e.sexAktivitaet.titel)") }
                    if !e.notizen.isEmpty { Text(e.notizen).lineLimit(2) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if badges.isEmpty {
                Text("Kein Eintrag").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20, padding: 0)
    }
}

// MARK: - Kalender-Legende

struct ZyklusKalenderLegende: View {
    var body: some View { kalenderLegende }

    private var kalenderLegende: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach([0.35, 0.6, 0.85, 1.0] as [Double], id: \.self) { op in
                    Circle().fill(ZyklusFarbe.periode.opacity(op)).frame(width: 7, height: 7)
                }
                Text("Periode")
            }
            legendeItem(ZyklusFarbe.periode, gestrichelt: true, text: "Vorhergesagt",
                        info: ("Vorhergesagte Periode",
                               "Geschätzter Periodenbeginn aus deinen bisherigen Zyklen (gewichteter Median der letzten 6). Die Abweichung ± Tage steht im Heute-Tab."))
            legendeItem(ZyklusFarbe.fruchtbar, gestrichelt: false, text: "Fruchtbar",
                        info: ("Fruchtbare Tage",
                               "Die 6 Tage bis einschließlich Eisprungtag (kräftig). Hellere Randtage zeigen die Unsicherheit der Prognose und sind bei bestätigtem Eisprung (Temperatur, LH-Test) verschwunden. Fruchtbarer Zervixschleim und positive LH-Tests markieren den Tag zusätzlich."))
            legendeItem(ZyklusFarbe.eisprung, gestrichelt: false, text: "Eisprung",
                        info: ("Eisprung (Ovulation)",
                               "Festgelegt per BBT-Anstieg (bestätigt), LH-Test oder Zervixschleim-Peak; sonst geschätzt als nächste Periode minus Lutealphase (Standard 14 Tage, persönlich gelernt ab 2 Zyklen mit Evidenz)."))
            HStack(spacing: 4) {
                Circle().fill(Color.purple.opacity(0.8)).frame(width: 7, height: 7)
                Text("Symptome")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.blue.opacity(0.8)).frame(width: 7, height: 7)
                Text("Zervixschleim")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.pink.opacity(0.8)).frame(width: 7, height: 7)
                Text("Sex. Aktivität")
            }
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(ZyklusFarbe.eisprung)
                Text("LH-Test positiv")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.gray.opacity(0.8)).frame(width: 7, height: 7)
                Text("Test / Temperatur / Notiz")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(14)
        .glassCard(radius: 18, padding: 0)
    }

    private func legendeItem(_ farbe: Color, gestrichelt: Bool, text: String, info: (String, String)) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gestrichelt ? farbe.opacity(0.15) : farbe)
                .overlay {
                    if gestrichelt {
                        Circle().stroke(farbe, style: StrokeStyle(lineWidth: 1, dash: [2]))
                    }
                }
                .frame(width: 9, height: 9)
            Text(text)
            InfoButton(titel: info.0, text: info.1)
        }
    }
}

// MARK: - „Heute erfasst" (reine Anzeige)

/// Zusammenfassung der an einem Tag erfassten Werte (Blutung, Schleim, LH, Temperatur, Symptome, Notiz).
struct ZyklusErfasstKarte: View {
    var titel = "HEUTE ERFASST"
    let sicht: ZyklusTagesSicht?

    private var symptome: [String] { ListenFeld.parse(sicht?.symptome ?? "") }

    private var hatInhalt: Bool {
        guard let s = sicht else { return false }
        return s.hatBlutung || s.schleim != .keine || s.lhTest != .keine || s.basaltemperatur > 0
            || !symptome.isEmpty || s.sexAktivitaet != .keine || !s.notizen.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            if let s = sicht, hatInhalt {
                if s.hatBlutung {
                    zeile("drop.fill", ZyklusFarbe.periode, "Blutung", s.fluss == .keine ? "Ja" : s.fluss.titel)
                }
                if s.schleim != .keine { zeile("water.waves", .blue, "Zervixschleim", s.schleim.titel) }
                if s.lhTest != .keine { zeile("testtube.2", ZyklusFarbe.eisprung, "Ovulationstest", s.lhTest.titel) }
                if s.basaltemperatur > 0 {
                    zeile("thermometer.medium", .gray, "Basaltemperatur", String(format: "%.2f °C", s.basaltemperatur))
                }
                if s.sexAktivitaet != .keine { zeile("heart.fill", .pink, "Sexuelle Aktivität", s.sexAktivitaet.titel) }
                if !symptome.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Symptome", systemImage: "heart.text.square")
                            .font(.caption.weight(.semibold)).foregroundStyle(.purple)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
                            ForEach(symptome, id: \.self) { sym in
                                Text(sym)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(Color.purple.opacity(0.18), in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                            }
                        }
                    }
                }
                if !s.notizen.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Notiz", systemImage: "note.text")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(s.notizen).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Heute nichts erfasst").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20, padding: 0)
    }

    private func zeile(_ symbol: String, _ farbe: Color, _ label: String, _ wert: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(farbe)
                .frame(width: 30, height: 30)
                .background(Circle().fill(farbe.opacity(0.18)))
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(wert).font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}
