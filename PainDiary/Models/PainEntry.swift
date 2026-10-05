import Combine
import Foundation
import SwiftData

@Model final class PainEntry {
    var datum: Date = Date()
    var schmerzstaerke: Int = 5       // 0–10
    var koerperstelle: String = ""
    var schmerzart: String = ""
    var dauerMinuten: Int = 0
    var ausloeser: String = ""
    var begleiterscheinungen: String = ""
    var massnahmen: String = ""
    var notizen: String = ""
    var stimmung: Int = 3             // 1–5
    var schlafStunden: Double = 0
    var stressLevel: Int = 3          // 1–5
    var morgensteifigkeit: Int = 0    // Minuten, 0 = nicht erfasst
    var istSchub: Bool = false        // Rheuma-Schub / Flare
    var fatigue: Int = 0              // Erschöpfung 0–10, 0 = nicht erfasst
    var energielevel: Int = 0        // 1–5, 0 = nicht erfasst
    var gelenkStatus: String = ""     // "R_K:1,L_K:2,…" — GelenkStatusCoder

    // Wetter zum Zeitpunkt der Erfassung
    var wetterTemperatur: Double?
    var wetterCode: Int?
    var wetterWind: Double?

    // Haut-Eintrag Felder
    var istHautEintrag: Bool = false
    var hautStellen: String = ""
    var hautArt: String = ""
    var fotoDateiname: String = ""
    var verlauf: String = ""   // "besser" | "gleich" | "schlechter" | ""

    // Datenmodell v2 (lightweight migration — Defaults, Backfill durch DatenPflege)
    /// `EintragArt.rawValue`; leer = Altdaten, dann gilt die Legacy-Regel (siehe `eintragsArt`).
    var artRaw: String = ""
    /// IANA-Zeitzone zum Zeitpunkt der Erfassung (z. B. "Europe/Zurich"); leer = unbekannt.
    var timeZoneID: String = ""

    init(
        datum: Date = .now,
        schmerzstaerke: Int = 5,
        koerperstelle: String = "",
        schmerzart: String = "",
        dauerMinuten: Int = 0,
        ausloeser: String = "",
        begleiterscheinungen: String = "",
        massnahmen: String = "",
        notizen: String = "",
        stimmung: Int = 0,
        schlafStunden: Double = 0,
        stressLevel: Int = 0,
        morgensteifigkeit: Int = 0,
        istSchub: Bool = false,
        fatigue: Int = 0,
        energielevel: Int = 0,
        gelenkStatus: String = "",
        wetterTemperatur: Double? = nil,
        wetterCode: Int? = nil,
        wetterWind: Double? = nil,
        hautStellen: String = "",
        hautArt: String = "",
        fotoDateiname: String = "",
        verlauf: String = ""
    ) {
        self.datum = datum
        self.schmerzstaerke = schmerzstaerke
        self.koerperstelle = koerperstelle
        self.schmerzart = schmerzart
        self.dauerMinuten = dauerMinuten
        self.ausloeser = ausloeser
        self.begleiterscheinungen = begleiterscheinungen
        self.massnahmen = massnahmen
        self.notizen = notizen
        self.stimmung = stimmung
        self.schlafStunden = schlafStunden
        self.stressLevel = stressLevel
        self.morgensteifigkeit = morgensteifigkeit
        self.istSchub = istSchub
        self.fatigue = fatigue
        self.energielevel = energielevel
        self.gelenkStatus = gelenkStatus
        self.wetterTemperatur = wetterTemperatur
        self.wetterCode = wetterCode
        self.wetterWind = wetterWind
        self.hautStellen = hautStellen
        self.hautArt = hautArt
        self.fotoDateiname = fotoDateiname
        self.verlauf = verlauf
        self.timeZoneID = TimeZone.current.identifier
    }
}

// MARK: - Abgeleitete Eigenschaften

extension PainEntry {
    /// Typ des Eintrags. Neue Einträge nutzen `artRaw`, Altdaten fallen auf die Legacy-Regel zurück.
    var eintragsArt: EintragArt {
        get {
            EintragArt(rawValue: artRaw)
                ?? EintragArt.ausLegacy(koerperstelle: koerperstelle, istHautEintrag: istHautEintrag)
        }
        set {
            artRaw = newValue.rawValue
            // Legacy-Felder konsistent halten (Exporte, Altlogik)
            istHautEintrag = newValue == .haut
            if newValue == .rheuma { koerperstelle = EintragArt.rheumaMarker }
        }
    }

    var zeitzone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// Kalendertag in der Erfassungs-Zeitzone.
    var tag: DayKey { DayKey(datum, zeitzone: zeitzone) }

    /// Körperstellen als Liste.
    var koerperstellenListe: [String] { ListenFeld.parse(koerperstelle) }
    var ausloeserListe: [String] { ListenFeld.parse(ausloeser) }
}
