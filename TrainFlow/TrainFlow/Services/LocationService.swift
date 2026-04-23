import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    /// Requests location permission (if needed), obtains the current location,
    /// reverse-geocodes it, and PUTs the result to /profile.
    func requestLocationAndUpdate() async {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Allow time for the system auth prompt to resolve
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        let granted: Bool
        #if os(iOS)
        granted = manager.authorizationStatus == .authorizedWhenInUse
               || manager.authorizationStatus == .authorizedAlways
        #else
        granted = manager.authorizationStatus == .authorized
               || manager.authorizationStatus == .authorizedAlways
        #endif
        guard granted else {
            NSLog("[LocationService] Location permission not granted")
            return
        }

        guard let location = await getCurrentLocation() else {
            NSLog("[LocationService] Could not obtain current location")
            return
        }

        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let placemark = placemarks.first else {
            NSLog("[LocationService] Reverse geocoding failed")
            return
        }

        let city = placemark.locality ?? placemark.administrativeArea ?? ""
        let country = placemark.country ?? ""
        let climateZone = inferClimateZone(
            lat: location.coordinate.latitude,
            country: country,
            city: city
        )

        struct LocationUpdate: Encodable {
            let location: LocationData
            struct LocationData: Encodable {
                let lat: Double
                let lon: Double
                let city: String
                let country: String
                let climateZone: String
            }
        }

        let update = LocationUpdate(location: .init(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            city: city,
            country: country,
            climateZone: climateZone
        ))

        do {
            let _: [String: String] = try await APIClient.shared.put("/profile", body: update)
            NSLog("[LocationService] Updated location: \(city), \(country), zone: \(climateZone)")
        } catch {
            NSLog("[LocationService] Failed to update location: \(error.localizedDescription)")
        }
    }

    // MARK: - CLLocationManager

    private func getCurrentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.first)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        NSLog("[LocationService] CLLocationManager error: \(error.localizedDescription)")
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }

    // MARK: - Climate Zone Inference

    private func inferClimateZone(lat: Double, country: String, city: String) -> String {
        let absLat = abs(lat)

        // High-altitude cities (approximation by known city list)
        let highAltitudeCities = [
            "Leh", "Manali", "Shimla", "Darjeeling", "Kathmandu",
            "Addis Ababa", "Nairobi", "Bogotá", "Quito", "La Paz",
            "Denver", "Mexico City"
        ]
        if highAltitudeCities.contains(where: { city.contains($0) }) {
            return "high_altitude"
        }

        // Hot & humid: tropics + coastal South/Southeast Asia
        let hotHumidCountries = [
            "India", "Thailand", "Malaysia", "Indonesia", "Philippines",
            "Vietnam", "Bangladesh", "Sri Lanka", "Singapore"
        ]
        if absLat < 23 && hotHumidCountries.contains(country) {
            return "hot_humid"
        }

        // Hot & arid: Middle East / North Africa desert belt
        let hotAridCountries = [
            "Saudi Arabia", "UAE", "Qatar", "Kuwait", "Bahrain",
            "Oman", "Iraq", "Iran", "Egypt", "Libya", "Algeria"
        ]
        if absLat < 35 && hotAridCountries.contains(country) {
            return "hot_arid"
        }

        // Cold: high latitudes and known cold-climate countries
        let coldCountries = ["Russia", "Canada", "Norway", "Sweden", "Finland", "Iceland"]
        if absLat > 55 || coldCountries.contains(country) {
            return "cold"
        }

        return "temperate"
    }
}
