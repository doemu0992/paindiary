import Foundation
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif

struct ZyklusHealthErgebnis {
    var importiert = 0
    var exportiert = 0
    var fehler: String? = nil
}

/// Abgleich der Zyklusdaten mit Apple Health (Cycle Tracking).
///
/// Mapping 1:1 auf HealthKit-Typen:
/// - Blutung            ↔ `menstrualFlow` (+ `HKMetadataKeyMenstrualCycleStart` am Zyklusstart)
/// - Schmierblutung     ↔ `intermenstrualBleeding`
/// - Zervixschleim      ↔ `cervicalMucusQuality` (dry/sticky/creamy/watery/eggWhite)
/// - Ovulationstest     ↔ `ovulationTestResult`
/// - Basaltemperatur    ↔ `basalBodyTemperature` (°C)
/// - Sexuelle Aktivität ↔ `sexualActivity` (+ `HKMetadataKeySexualActivityProtectionUsed`)
///
/// Import füllt nur *leere* Felder (manuelle Eingaben werden nie überschrieben) und ignoriert Samples
/// dieser App (kein Echo). Export nutzt Sync-Identifier, sodass erneutes Schreiben bestehende
/// Samples ersetzt statt zu duplizieren. Gelöschte Felder werden nicht aus Health entfernt.
@MainActor
final class ZyklusHealthKitService {
    static let shared = ZyklusHealthKitService()
    private init() {}

    var istVerfuegbar: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    #if canImport(HealthKit)

    private let store = HKHealthStore()

    private var kategorieTypen: [HKCategoryType] {
        [
            HKCategoryType(.menstrualFlow),
            HKCategoryType(.intermenstrualBleeding),
            HKCategoryType(.cervicalMucusQuality),
            HKCategoryType(.ovulationTestResult),
            HKCategoryType(.sexualActivity)
        ]
    }

    private var bbtTyp: HKQuantityType { HKQuantityType(.basalBodyTemperature) }

    func berechtigungAnfordern() async -> Bool {
        guard istVerfuegbar else { return false }
        var schreiben = Set<HKSampleType>(kategorieTypen.map { $0 as HKSampleType })
        schreiben.insert(bbtTyp)
        var lesen = Set<HKObjectType>(kategorieTypen.map { $0 as HKObjectType })
        lesen.insert(bbtTyp)
        do {
            try await store.requestAuthorization(toShare: schreiben, read: lesen)
            return true
        } catch {
            return false
        }
    }

    /// Import (Health → App) und anschließend Export (App → Health).
    func abgleichen(context: ModelContext, eintraege: [ZyklusEintrag]) async -> ZyklusHealthErgebnis {
        var ergebnis = ZyklusHealthErgebnis()
        guard istVerfuegbar else {
            ergebnis.fehler = "Apple Health ist auf diesem Gerät nicht verfügbar."
            return ergebnis
        }
        guard await berechtigungAnfordern() else {
            ergebnis.fehler = "Zugriff auf Apple Health wurde nicht gewährt."
            return ergebnis
        }
        do {
            ergebnis.importiert = try await importieren(context: context, vorhandene: eintraege)
        } catch {
            ergebnis.fehler = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
        do {
            ergebnis.exportiert = try await exportieren(eintraege: eintraege)
        } catch {
            let text = "Export fehlgeschlagen: \(error.localizedDescription)"
            ergebnis.fehler = ergebnis.fehler.map { $0 + "\n" + text } ?? text
        }
        return ergebnis
    }

    // MARK: - Import

    private func kategorieSamples(_ typ: HKCategoryType, seit: Date) async throws -> [HKCategorySample] {
        let pred = HKQuery.predicateForSamples(withStart: seit, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: typ, predicate: pred)],
            sortDescriptors: [SortDescriptor(\.startDate)],
            limit: HKObjectQueryNoLimit
        )
        let alle = try await descriptor.result(for: store)
        return alle.filter { $0.sourceRevision.source != HKSource.default() }
    }

    func importieren(context: ModelContext, vorhandene: [ZyklusEintrag]) async throws -> Int {
        let kal = Calendar.current
        let seit = kal.date(byAdding: .year, value: -2, to: Date()) ?? Date.distantPast

        var proTag: [Date: ZyklusEintrag] = [:]
        for e in vorhandene {
            let tag = e.tag.beginn(in: kal.timeZone)
            if proTag[tag] == nil { proTag[tag] = e }
        }
        var geaendert = 0

        func eintrag(fuer datum: Date) -> ZyklusEintrag {
            let tag = kal.startOfDay(for: datum)
            if let e = proTag[tag] { return e }
            let neu = ZyklusEintrag(datum: tag)
            neu.quelle = "health"
            context.insert(neu)
            proTag[tag] = neu
            return neu
        }

        // Blutung (menstrualFlow: 1 unspecified, 2 light, 3 medium, 4 heavy, 5 none)
        for s in try await kategorieSamples(HKCategoryType(.menstrualFlow), seit: seit) {
            let fluss: Blutungsfluss
            switch s.value {
            case 2:  fluss = .leicht
            case 4:  fluss = .stark
            case 1, 3: fluss = .mittel
            default: continue   // 5 = keine Blutung
            }
            let e = eintrag(fuer: s.startDate)
            if !e.hatBlutung {
                e.istPeriode = true
                e.fluss = fluss
                geaendert += 1
            }
        }

        // Zwischenblutung → Schmierblutung
        for s in try await kategorieSamples(HKCategoryType(.intermenstrualBleeding), seit: seit) {
            let e = eintrag(fuer: s.startDate)
            if !e.hatBlutung {
                e.istPeriode = true
                e.fluss = .schmierblutung
                geaendert += 1
            }
        }

        // Zervixschleim (1 dry, 2 sticky, 3 creamy, 4 watery, 5 eggWhite)
        for s in try await kategorieSamples(HKCategoryType(.cervicalMucusQuality), seit: seit) {
            let wert: Zervixschleim
            switch s.value {
            case 1: wert = .trocken
            case 2: wert = .klebrig
            case 3: wert = .cremig
            case 4: wert = .waessrig
            case 5: wert = .eiweiss
            default: continue
            }
            let e = eintrag(fuer: s.startDate)
            if e.schleim == .keine {
                e.schleim = wert
                geaendert += 1
            }
        }

        // Ovulationstest (1 negative, 2 LH-Anstieg/positiv, 3 indeterminate, 4 estrogenSurge)
        for s in try await kategorieSamples(HKCategoryType(.ovulationTestResult), seit: seit) {
            let wert: LHTest
            switch s.value {
            case 1: wert = .negativ
            case 2: wert = .positiv
            case 3, 4: wert = .unklar
            default: continue
            }
            let e = eintrag(fuer: s.startDate)
            if e.lhTest == .keine {
                e.lhTest = wert
                geaendert += 1
            }
        }

        // Sexuelle Aktivität — nur mit Schutz-Metadaten (sonst wäre die Angabe geraten)
        for s in try await kategorieSamples(HKCategoryType(.sexualActivity), seit: seit) {
            guard let geschuetzt = s.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool else { continue }
            let e = eintrag(fuer: s.startDate)
            if e.sexAktivitaet == .keine {
                e.sexAktivitaet = geschuetzt ? .geschuetzt : .ungeschuetzt
                geaendert += 1
            }
        }

        // Basaltemperatur (°C), pro Tag der letzte Wert
        let pred = HKQuery.predicateForSamples(withStart: seit, end: nil, options: .strictStartDate)
        let bbtDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bbtTyp, predicate: pred)],
            sortDescriptors: [SortDescriptor(\.startDate)],
            limit: HKObjectQueryNoLimit
        )
        let bbtSamples = try await bbtDescriptor.result(for: store)
        for s in bbtSamples where s.sourceRevision.source != HKSource.default() {
            let grad = s.quantity.doubleValue(for: .degreeCelsius())
            guard ZyklusGrenzen.bbtBereich.contains(grad) else { continue }
            let e = eintrag(fuer: s.startDate)
            if e.basaltemperatur == 0 {
                e.basaltemperatur = (grad * 100).rounded() / 100
                geaendert += 1
            }
        }

        return geaendert
    }

    // MARK: - Export

    func exportieren(eintraege: [ZyklusEintrag]) async throws -> Int {
        let kal = Calendar.current
        let analyse = ZyklusRechner.analyse(eintraege: eintraege)
        let version = NSNumber(value: Int(Date().timeIntervalSince1970))
        var objekte: [HKObject] = []

        for e in eintraege where !e.kommtAusHealth {
            // Tag in der Erfassungs-Zeitzone des Eintrags (DayKey) — nicht in der aktuellen Gerätezeitzone
            let tagKey = e.tag
            var eintragsKalender = Calendar(identifier: .gregorian)
            eintragsKalender.timeZone = e.zeitzone
            let tag = tagKey.beginn(in: e.zeitzone)
            let ende = (eintragsKalender.date(byAdding: .day, value: 1, to: tag) ?? tag).addingTimeInterval(-1)
            let kennung = String(format: "%08ld", tagKey.wert)

            func metadaten(_ art: String, _ extra: [String: Any] = [:]) -> [String: Any] {
                var m = extra
                m[HKMetadataKeySyncIdentifier] = "paindiary-zyklus-\(kennung)-\(art)"
                m[HKMetadataKeySyncVersion] = version
                return m
            }

            if e.istMenstruation {
                let wert: Int
                switch e.fluss {
                case .leicht: wert = 2
                case .mittel: wert = 3
                case .stark:  wert = 4
                default:      wert = 1   // unspecified
                }
                var extra: [String: Any] = [:]
                if analyse.zyklusStarts.contains(where: { DayKey($0, zeitzone: kal.timeZone) == tagKey }) {
                    extra[HKMetadataKeyMenstrualCycleStart] = true
                }
                objekte.append(HKCategorySample(type: HKCategoryType(.menstrualFlow), value: wert,
                                                start: tag, end: ende, metadata: metadaten("fluss", extra)))
            } else if e.istSpotting {
                objekte.append(HKCategorySample(type: HKCategoryType(.intermenstrualBleeding), value: 0,
                                                start: tag, end: ende, metadata: metadaten("spotting")))
            }

            let schleimWert: Int?
            switch e.schleim {
            case .trocken:  schleimWert = 1
            case .klebrig:  schleimWert = 2
            case .cremig:   schleimWert = 3
            case .waessrig: schleimWert = 4
            case .eiweiss:  schleimWert = 5
            case .keine:    schleimWert = nil
            }
            if let w = schleimWert {
                objekte.append(HKCategorySample(type: HKCategoryType(.cervicalMucusQuality), value: w,
                                                start: tag, end: ende, metadata: metadaten("schleim")))
            }

            let lhWert: Int?
            switch e.lhTest {
            case .negativ: lhWert = 1
            case .positiv: lhWert = 2
            case .unklar:  lhWert = 3
            case .keine:   lhWert = nil
            }
            if let w = lhWert {
                objekte.append(HKCategorySample(type: HKCategoryType(.ovulationTestResult), value: w,
                                                start: tag, end: ende, metadata: metadaten("lh")))
            }

            if ZyklusGrenzen.bbtBereich.contains(e.basaltemperatur) {
                let zeit = tag.addingTimeInterval(6 * 3600)
                let menge = HKQuantity(unit: .degreeCelsius(), doubleValue: e.basaltemperatur)
                objekte.append(HKQuantitySample(type: bbtTyp, quantity: menge,
                                                start: zeit, end: zeit, metadata: metadaten("bbt")))
            }

            if e.sexAktivitaet != .keine {
                let extra: [String: Any] = [HKMetadataKeySexualActivityProtectionUsed: e.sexAktivitaet == .geschuetzt]
                objekte.append(HKCategorySample(type: HKCategoryType(.sexualActivity), value: 0,
                                                start: tag, end: ende, metadata: metadaten("sex", extra)))
            }
        }

        guard !objekte.isEmpty else { return 0 }
        try await store.save(objekte)
        return objekte.count
    }

    #else

    func berechtigungAnfordern() async -> Bool { false }

    func abgleichen(context: ModelContext, eintraege: [ZyklusEintrag]) async -> ZyklusHealthErgebnis {
        ZyklusHealthErgebnis(importiert: 0, exportiert: 0, fehler: "Apple Health ist nicht verfügbar.")
    }

    #endif
}
