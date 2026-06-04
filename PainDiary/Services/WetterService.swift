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

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func laden() {
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
        guard let loc = locations.first else { return }
        Task { await fetchWetter(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.fehler = "Standort nicht verfügbar"
        self.isLoading = false
    }

    private func fetchWetter(lat: Double, lon: Double) async {
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code,wind_speed_10m,surface_pressure"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            await MainActor.run {
                self.aktuell = WetterSnapshot(
                    temperatur: r.current.temperature_2m,
                    code: r.current.weather_code,
                    windgeschwindigkeit: r.current.wind_speed_10m,
                    luftdruckHpa: r.current.surface_pressure
                )
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

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather
    struct CurrentWeather: Codable {
        let temperature_2m: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let surface_pressure: Double?
    }
}
