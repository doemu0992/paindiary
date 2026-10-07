import Foundation

// MARK: - Medikamentenübergebrauch (MOH)

nonisolated enum UebergebrauchStufe: String, Sendable {
    case unauffaellig, nahe, ueberschritten
}

nonisolated struct UebergebrauchStatus: Equatable, Sendable {
    let tageMitAkutmedikation: Int
    let schwelle: Int
    let stufe: UebergebrauchStufe
}

/// Prüft, an wie vielen Tagen im Zeitfenster Akutmedikation genommen wurde.
///
/// Orientierung (ICHD-3, Kopfschmerz bei Medikamentenübergebrauch): Triptane/Kombinationspräparate
/// ≥ 10 Tage/Monat, einfache Analgetika ≥ 15 Tage/Monat. Die App gibt nur einen **Hinweis**,
/// keine Diagnose; die Schwelle ist konfigurierbar.
nonisolated enum Uebergebrauch {
    static let schwelleTriptane = 10
    static let schwelleAnalgetika = 15

    static func pruefe(einnahmeTage: [DayKey], heute: DayKey, fensterTage: Int = 30, schwelle: Int = schwelleTriptane) -> UebergebrauchStatus {
        let von = heute.addiere(tage: -(fensterTage - 1))
        let tage = Set(einnahmeTage.filter { $0 >= von && $0 <= heute }).count
        let stufe: UebergebrauchStufe
        if tage >= schwelle { stufe = .ueberschritten }
        else if Double(tage) >= Double(schwelle) * 0.8 { stufe = .nahe }
        else { stufe = .unauffaellig }
        return UebergebrauchStatus(tageMitAkutmedikation: tage, schwelle: schwelle, stufe: stufe)
    }
}

// MARK: - Wirksamkeit einer Einnahme

nonisolated struct WirksamkeitsErgebnis: Equatable, Sendable {
    /// Anzahl Einnahmen mit Schmerzwert vorher **und** nachher.
    let paare: Int
    /// Mittlere Veränderung (nachher − vorher). Negativ = Schmerz sank.
    let mittlereVeraenderung: Double
    let besserungsquote: Double   // Anteil der Paare mit Besserung (0…1)
}

nonisolated enum Wirksamkeit {
    /// Vergleicht je Einnahme den letzten Schmerzwert in den `vorStunden` davor mit dem
    /// ersten Wert im Fenster `nachMinStunden...nachMaxStunden` danach.
    static func auswerten(
        einnahmen: [Date],
        schmerz: [(datum: Date, staerke: Int)],
        vorStunden: Double = 3,
        nachMinStunden: Double = 1,
        nachMaxStunden: Double = 6
    ) -> WirksamkeitsErgebnis? {
        let sortiert = schmerz.sorted { $0.datum < $1.datum }
        var differenzen: [Double] = []
        for e in einnahmen {
            let vor = sortiert.last { $0.datum <= e && e.timeIntervalSince($0.datum) <= vorStunden * 3600 }
            let nach = sortiert.first {
                let d = $0.datum.timeIntervalSince(e)
                return d >= nachMinStunden * 3600 && d <= nachMaxStunden * 3600
            }
            if let v = vor, let n = nach { differenzen.append(Double(n.staerke - v.staerke)) }
        }
        guard !differenzen.isEmpty, let m = Statistik.mittelwert(differenzen) else { return nil }
        let besser = differenzen.filter { $0 < 0 }.count
        return WirksamkeitsErgebnis(paare: differenzen.count, mittlereVeraenderung: m,
                                    besserungsquote: Double(besser) / Double(differenzen.count))
    }
}

// MARK: - Schub-/Verschlechterungs-Erkennung

nonisolated struct SchubHinweis: Equatable, Sendable {
    let aktuellerMittelwert: Double
    let baselineMittelwert: Double
    let abweichungen: Double   // in Standardabweichungen der Baseline
}

nonisolated enum SchubErkennung {
    /// Vergleicht die letzten `akutTage` mit der persönlichen Baseline der `baselineTage` davor.
    /// Hinweis, wenn der Mittelwert mehr als `schwelleSigma` Standardabweichungen **und** mindestens
    /// `minAnstieg` Punkte über der Baseline liegt. Braucht ausreichend Datenpunkte.
    static func pruefe(
        _ reihe: [TagesWert], heute: DayKey,
        akutTage: Int = 3, baselineTage: Int = 28,
        schwelleSigma: Double = 1.5, minAnstieg: Double = 1.5, minBaselinePunkte: Int = 7
    ) -> SchubHinweis? {
        let akutVon = heute.addiere(tage: -(akutTage - 1))
        let baseBis = akutVon.addiere(tage: -1)
        let baseVon = baseBis.addiere(tage: -(baselineTage - 1))

        let akut = reihe.filter { $0.tag >= akutVon && $0.tag <= heute }.map(\.wert)
        let basis = reihe.filter { $0.tag >= baseVon && $0.tag <= baseBis }.map(\.wert)
        guard !akut.isEmpty, basis.count >= minBaselinePunkte,
              let ma = Statistik.mittelwert(akut), let mb = Statistik.mittelwert(basis) else { return nil }

        // Mindeststreuung, damit eine sehr gleichmäßige Baseline nicht zu Fehlalarmen führt
        let sd = max(Statistik.standardabweichung(basis) ?? 0, 0.5)
        let sigma = (ma - mb) / sd
        guard sigma >= schwelleSigma, ma - mb >= minAnstieg else { return nil }
        return SchubHinweis(aktuellerMittelwert: ma, baselineMittelwert: mb, abweichungen: sigma)
    }
}

// MARK: - Schlaf (HealthKit-Rohdaten → Stunden)

nonisolated struct SchlafSegment: Equatable, Sendable {
    let start: Date
    let ende: Date
}

nonisolated enum SchlafAggregator {
    /// Summiert Schlafsegmente **ohne Doppelzählung**: überlappende Segmente (z. B. iPhone + Apple Watch)
    /// werden vereinigt. Der Aufrufer liefert nur echte Schlafphasen (keine „im Bett"/„wach"-Segmente).
    static func stunden(aus segmente: [SchlafSegment]) -> Double {
        let gueltig = segmente.filter { $0.ende > $0.start }.sorted { $0.start < $1.start }
        guard var aktuell = gueltig.first else { return 0 }
        var summe: TimeInterval = 0
        for s in gueltig.dropFirst() {
            if s.start <= aktuell.ende {
                if s.ende > aktuell.ende { aktuell = SchlafSegment(start: aktuell.start, ende: s.ende) }
            } else {
                summe += aktuell.ende.timeIntervalSince(aktuell.start)
                aktuell = s
            }
        }
        summe += aktuell.ende.timeIntervalSince(aktuell.start)
        return summe / 3600
    }

    /// Fenster der „letzten Nacht": gestern 18:00 bis heute 12:00 (Ortszeit).
    static func nachtFenster(heute: Date = Date(), kalender: Calendar = .current) -> (von: Date, bis: Date) {
        let tagesbeginn = kalender.startOfDay(for: heute)
        let bis = kalender.date(byAdding: .hour, value: 12, to: tagesbeginn) ?? heute
        let gestern = kalender.date(byAdding: .day, value: -1, to: tagesbeginn) ?? tagesbeginn
        let von = kalender.date(byAdding: .hour, value: 18, to: gestern) ?? gestern
        return (von, bis)
    }
}
