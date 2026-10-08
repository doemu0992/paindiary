import Foundation
import Observation

/// Mini-Kennzahl eines Moduls fürs Carousel der Einblicke.
struct ModulMini: Equatable {
    let wert: String
    let einheit: String?
    let verlauf: [Double]
}

/// Bereitet alle Daten der „Einblicke" auf. Rechnet ausschließlich über Domain-Typen
/// (`VerlaufUebersicht`, `MedikationsUebersicht`, `*Uebersicht`); die View enthält keine Berechnungslogik.
@Observable
@MainActor
final class VerlaufDashboardViewModel {
    private(set) var verlauf = VerlaufUebersicht()
    private(set) var medikation = MedikationsUebersicht()
    private(set) var aktiveMedikamente = 0
    private(set) var minis: [EinblickeBlock: ModulMini] = [:]

    private let schmerzVM = SchmerzDashboardViewModel()
    private let migraeneVM = MigraeneDashboardViewModel()
    private let rheumaVM = RheumaDashboardViewModel()
    private let hautVM = HautDashboardViewModel()
    private let diabetesVM = DiabetesDashboardViewModel()
    private let medVM = MedikamenteDashboardViewModel()

    func aktualisiere(
        eintraege: [PainEntry],
        migraene: [MigraeneEintrag],
        blutzucker: [BlutzuckerEintrag],
        zyklus: [ZyklusEintrag],
        wellness: [WellnessEintrag],
        medikamente: [Dauermedikation],
        logs: [EinnahmeLog],
        jetzt: Date = Date()
    ) {
        let heute = DayKey.heute(jetzt: jetzt)

        let punkte = eintraege
            .filter { $0.eintragsArt == .schmerz }
            .map {
                VerlaufMesspunkt(
                    datum: $0.datum, tag: $0.tag, staerke: $0.schmerzstaerke, istSchub: $0.istSchub,
                    ausloeser: $0.ausloeserListe, stimmung: $0.stimmung, stress: $0.stressLevel,
                    schlafStunden: $0.schlafStunden
                )
            }
        verlauf = VerlaufUebersicht.berechne(punkte: punkte, heute: heute)

        medVM.aktualisiere(medikamente: medikamente, logs: logs, jetzt: jetzt)
        medikation = medVM.uebersicht
        aktiveMedikamente = medikamente.filter(\.aktiv).count

        schmerzVM.aktualisiere(eintraege: eintraege, jetzt: jetzt)
        migraeneVM.aktualisiere(anfaelle: migraene, jetzt: jetzt)
        rheumaVM.aktualisiere(eintraege: eintraege, jetzt: jetzt)
        hautVM.aktualisiere(eintraege: eintraege, jetzt: jetzt)
        diabetesVM.aktualisiere(messungen: blutzucker, jetzt: jetzt)

        var m: [EinblickeBlock: ModulMini] = [:]
        let s = schmerzVM.uebersicht
        m[.modulSchmerz] = ModulMini(wert: s.wochenSchnitt.map { String(format: "%.1f", $0) } ?? "–", einheit: "Ø 7 T", verlauf: s.verlauf7)
        let mi = migraeneVM.uebersicht
        m[.modulMigraene] = ModulMini(wert: "\(mi.anzahl30)", einheit: "Anfälle · 30 T", verlauf: [])
        let r = rheumaVM.uebersicht
        m[.modulRheuma] = ModulMini(wert: r.schnitt30.map { String(format: "%.1f", $0) } ?? "–", einheit: "Ø 30 T", verlauf: [])
        let h = hautVM.uebersicht
        m[.modulHaut] = ModulMini(wert: "\(h.anzahl30)", einheit: "Einträge · 30 T", verlauf: [])
        let d = diabetesVM.uebersicht
        m[.modulDiabetes] = ModulMini(wert: d.zielAnteil30.map { String(format: "%.0f%%", $0 * 100) } ?? "–", einheit: "im Ziel", verlauf: d.verlauf7)

        let zyklusTag = ZyklusRechner.analyse(eintraege: zyklus).aktuellerZyklustag
        m[.modulZyklus] = ModulMini(wert: zyklusTag.map { "\($0)" } ?? "–", einheit: "Zyklustag", verlauf: [])

        let von = heute.addiere(tage: -6)
        let wellnessTage = Set(wellness.map { DayKey($0.datum) }.filter { $0 >= von && $0 <= heute }).count
        m[.modulWellness] = ModulMini(wert: "\(wellnessTage)", einheit: "von 7 Tagen", verlauf: [])
        minis = m
    }
}
