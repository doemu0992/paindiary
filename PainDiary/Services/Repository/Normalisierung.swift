import Foundation
import SwiftData
import os

/// Stellt sicher, dass gespeicherte Werte in den gültigen Bereichen liegen (Einheitliche Quelle: `Wertebereich`).
/// Formulare, Schnellerfassung und Import rufen `einfuegenValidiert` statt `insert` auf.
@MainActor
enum Normalisierung {
    private static let logger = Logger(subsystem: "com.doemu0992.paindiary", category: "validierung")

    @discardableResult
    static func normalisiere(_ e: PainEntry, jetzt: Date = Date()) -> [Korrektur] {
        var k: [Korrektur] = []
        e.schmerzstaerke = Validierung.begrenze(e.schmerzstaerke, feld: "schmerzstaerke", bereich: Wertebereich.schmerz, korrekturen: &k)
        e.stimmung = Validierung.begrenze(e.stimmung, feld: "stimmung", bereich: Wertebereich.stimmung, korrekturen: &k)
        e.stressLevel = Validierung.begrenze(e.stressLevel, feld: "stressLevel", bereich: Wertebereich.stress, korrekturen: &k)
        e.energielevel = Validierung.begrenze(e.energielevel, feld: "energielevel", bereich: Wertebereich.energie, korrekturen: &k)
        e.fatigue = Validierung.begrenze(e.fatigue, feld: "fatigue", bereich: Wertebereich.fatigue, korrekturen: &k)
        e.dauerMinuten = Validierung.begrenze(e.dauerMinuten, feld: "dauerMinuten", bereich: Wertebereich.dauerMinuten, korrekturen: &k)
        e.morgensteifigkeit = Validierung.begrenze(e.morgensteifigkeit, feld: "morgensteifigkeit", bereich: Wertebereich.morgensteifigkeitMinuten, korrekturen: &k)
        e.schlafStunden = Validierung.begrenze(e.schlafStunden, feld: "schlafStunden", bereich: Wertebereich.schlafStunden, korrekturen: &k)
        e.datum = Validierung.begrenzeZukunft(e.datum, jetzt: jetzt, korrekturen: &k)
        e.koerperstelle = e.eintragsArt == .rheuma ? e.koerperstelle : ListenFeld.join(ListenFeld.parse(e.koerperstelle))
        if e.timeZoneID.isEmpty { e.timeZoneID = TimeZone.current.identifier }
        logge(k, "PainEntry")
        return k
    }

    @discardableResult
    static func normalisiere(_ e: MigraeneEintrag, jetzt: Date = Date()) -> [Korrektur] {
        var k: [Korrektur] = []
        e.staerke = Validierung.begrenze(e.staerke, feld: "staerke", bereich: Wertebereich.migraeneStaerke, korrekturen: &k)
        e.dauer = Validierung.begrenze(e.dauer, feld: "dauer", bereich: Wertebereich.dauerMinuten, korrekturen: &k)
        e.stimmung = Validierung.begrenze(e.stimmung, feld: "stimmung", bereich: Wertebereich.stimmung, korrekturen: &k)
        e.stressLevel = Validierung.begrenze(e.stressLevel, feld: "stressLevel", bereich: Wertebereich.stress, korrekturen: &k)
        e.energielevel = Validierung.begrenze(e.energielevel, feld: "energielevel", bereich: Wertebereich.energie, korrekturen: &k)
        e.fatigue = Validierung.begrenze(e.fatigue, feld: "fatigue", bereich: Wertebereich.fatigue, korrekturen: &k)
        e.schlafStunden = Validierung.begrenze(e.schlafStunden, feld: "schlafStunden", bereich: Wertebereich.schlafStunden, korrekturen: &k)
        e.datum = Validierung.begrenzeZukunft(e.datum, jetzt: jetzt, korrekturen: &k)
        if let ende = e.endZeit, ende < e.datum { e.endZeit = nil }   // Ende vor Beginn ist unmöglich
        if e.timeZoneID.isEmpty { e.timeZoneID = TimeZone.current.identifier }
        logge(k, "MigraeneEintrag")
        return k
    }

    private static func logge(_ k: [Korrektur], _ typ: String) {
        guard !k.isEmpty else { return }
        logger.notice("\(typ, privacy: .public): \(k.count) Wert(e) korrigiert")
    }
}

extension ModelContext {
    /// Normalisiert und fügt ein. Eingabefehler werden begrenzt, nie abgelehnt (Erfassung darf nicht scheitern).
    func einfuegenValidiert(_ eintrag: PainEntry) {
        Normalisierung.normalisiere(eintrag)
        insert(eintrag)
    }

    func einfuegenValidiert(_ anfall: MigraeneEintrag) {
        Normalisierung.normalisiere(anfall)
        insert(anfall)
    }

    /// Blutzucker außerhalb des Messbereichs ist ein Eingabefehler → wirft statt still zu korrigieren.
    func einfuegenValidiert(_ messung: BlutzuckerEintrag) throws {
        try Validierung.pruefeBlutzucker(messung.wert)
        if messung.timeZoneID.isEmpty { messung.timeZoneID = TimeZone.current.identifier }
        insert(messung)
    }
}
