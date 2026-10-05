import Foundation
import CoreLocation
import Observation

struct WetterSnapshot {
    let temperatur: Double
    let code: Int
    let windgeschwindigkeit: Double
    var luftdruckHpa: Double?

    var beschreibung: String { Self.beschreibungFuerCode(code) }
    var symbol: String { Self.symbolFuerCode(code) }

    var luftdruckText: String {
        guard let druck = luftdruckHpa else { return "" }
        return "\(Int(druck.rounded())) hPa"
    }

    static func beschreibungFuerCode(_ code: Int) -> String {
        switch code {
        case 0:       return "Klar"
        case 1, 2:    return "Meist klar"
        case 3:       return "Bewölkt"
        case 45, 48:  return "Nebel"
        case 51, 53:  return "Nieselregen"
        case 55:      return "Starker Niesel"
        case 61, 63:  return "Regen"
        case 65:      return "Starkregen"
        case 71, 73:  return "Schneefall"
        case 75:      return "Starker Schnee"
        case 80, 81:  return "Schauer"
        case 82:      return "Starke Schauer"
        case 95:      return "Gewitter"
        case 96, 99:  return "Gewitter mit Hagel"
        default:      return "Unbekannt"
        }
    }

    static func symbolFuerCode(_ code: Int) -> String {
        switch code {
        case 0:       return "sun.max.fill"
        case 1, 2:    return "cloud.sun.fill"
        case 3:       return "cloud.fill"
        case 45, 48:  return "cloud.fog.fill"
        case 51...55: return "cloud.drizzle.fill"
        case 61...65: return "cloud.rain.fill"
        case 71...75: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.fill"
        default:      return "cloud.fill"
        }
    }
}

@Observable
class WetterService: NSObject, CLLocationManagerDelegate {
    static let shared = WetterService()

    private let locationManager = CLLocationManager()
    private(set) var aktuell: WetterSnapshot? = nil
    private(set) var isLoading = false
    private(set) var fehler: String? = nil
    private var letzteAktualisierung: Date? = nil
    /// Letzter bekannter Standort (für historische Wetterabfragen nachträglich erfasster Einträge).
    private var letzterStandort: (lat: Double, lon: Double)? = nil
    private let cacheMinuten: Double = 30

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func laden() {
        // Daten weniger als 30 Minuten alt → GPS-Request sparen
        if let ts = letzteAktualisierung, aktuell != nil,
           Date().timeIntervalSince(ts) < cacheMinuten * 60 { return }
        guard !isLoading else { return }
        fehler = nil
        isLoading = true
        locationManager.requestWhenInUseAuthorization()
        // Only request location immediately if permission is already granted.
        // If status is .notDetermined the dialog appears asynchronously;
        // locationManagerDidChangeAuthorization will trigger the actual request.
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLoading { manager.requestLocation() }
        case .denied, .restricted:
            self.fehler = "Standortzugriff nicht erlaubt"
            self.isLoading = false
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        guard let loc = locations.first else { return }
        letzterStandort = (loc.coordinate.latitude, loc.coordinate.longitude)
        Task { await fetchWetter(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        self.fehler = "Standort nicht verfügbar"
        self.isLoading = false
    }

    private func fetchWetter(lat: Double, lon: Double) async {
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code,wind_speed_10m,surface_pressure"
        guard let url = URL(string: urlStr) else {
            await MainActor.run { self.fehler = "Wetterdaten nicht verfügbar"; self.isLoading = false }
            return
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let r = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            await MainActor.run {
                self.aktuell = WetterSnapshot(
                    temperatur: r.current.temperature_2m,
                    code: r.current.weather_code,
                    windgeschwindigkeit: r.current.wind_speed_10m,
                    luftdruckHpa: r.current.surface_pressure
                )
                self.letzteAktualisierung = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.fehler = "Wetterdaten nicht verfügbar"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Historisches Wetter (nachträglich erfasste Einträge)

extension WetterService {
    /// Setzt die Wetterwerte eines Eintrags passend zu **seinem** Zeitpunkt (statt dem aktuellen Wetter).
    /// Schlägt die Abfrage fehl, bleiben die Felder leer — ein fehlender Wert ist besser als ein falscher.
    func historischeWerteSetzen(fuer eintrag: PainEntry) async {
        guard let snap = await wetterFuer(datum: eintrag.datum) else { return }
        eintrag.wetterTemperatur = snap.temperatur
        eintrag.wetterCode = snap.code
        eintrag.wetterWind = snap.windgeschwindigkeit
    }

    /// Wetter zum angegebenen Zeitpunkt (bis ca. 3 Monate zurück). `nil` ohne Standort/Netz.
    func wetterFuer(datum: Date) async -> WetterSnapshot? {
        if abs(datum.timeIntervalSinceNow) < 90 * 60 { return aktuell }
        guard let ort = letzterStandort, datum > Date().addingTimeInterval(-90 * 86_400) else { return nil }
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(ort.lat)&longitude=\(ort.lon)"
            + "&hourly=temperature_2m,weather_code,wind_speed_10m,surface_pressure"
            + "&past_days=92&forecast_days=1&timezone=auto"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let r = try JSONDecoder().decode(OpenMeteoStundenResponse.self, from: data)
            // „time" ist lokale Ortszeit (yyyy-MM-dd'T'HH:mm) → Zielstunde in Ortszeit bilden
            var kal = Calendar(identifier: .gregorian)
            kal.timeZone = TimeZone(secondsFromGMT: r.utc_offset_seconds) ?? .gmt
            let c = kal.dateComponents([.year, .month, .day, .hour], from: datum)
            let ziel = String(format: "%04d-%02d-%02dT%02d:00", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0)
            guard let i = r.hourly.time.firstIndex(of: ziel),
                  let temp = r.hourly.temperature_2m[safe: i] ?? nil,
                  let code = r.hourly.weather_code[safe: i] ?? nil,
                  let wind = r.hourly.wind_speed_10m[safe: i] ?? nil else { return nil }
            return WetterSnapshot(temperatur: temp, code: code, windgeschwindigkeit: wind,
                                  luftdruckHpa: r.hourly.surface_pressure[safe: i] ?? nil)
        } catch {
            return nil
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct OpenMeteoStundenResponse: Codable {
    let utc_offset_seconds: Int
    let hourly: Stuendlich
    struct Stuendlich: Codable {
        let time: [String]
        let temperature_2m: [Double?]
        let weather_code: [Int?]
        let wind_speed_10m: [Double?]
        let surface_pressure: [Double?]
    }
}

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather
    struct CurrentWeather: Codable {
        let temperature_2m: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let surface_pressure: Double?
    }
}
