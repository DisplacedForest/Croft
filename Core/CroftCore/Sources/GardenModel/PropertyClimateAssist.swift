import Domain
import Foundation

extension PropertyDetailsForm {
    public func adjustZone() {
        zoneSource = .user
    }

    public func adjustFrostDates() {
        frostDatesSource = .user
    }

    public func useDerivedZone() async {
        zoneSource = .derived
        zoneText = derivedClimate?.zone.map(String.init) ?? ""
        await deriveClimate()
    }

    public func useDerivedFrostDates() async {
        frostDatesSource = .derived
        lastFrostMonth = derivedClimate?.lastFrost?.month
        lastFrostDay = derivedClimate?.lastFrost?.day
        firstFrostMonth = derivedClimate?.firstFrost?.month
        firstFrostDay = derivedClimate?.firstFrost?.day
        await deriveClimate()
    }

    public var canSearchAddresses: Bool {
        addressSearch != nil
    }

    public func searchAddresses() async {
        guard let addressSearch else {
            return
        }
        let query = addressQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else {
            addressSuggestions = []
            return
        }
        addressSuggestions = await addressSearch.suggestions(for: query)
    }

    public func selectSuggestion(_ suggestion: AddressSuggestion) async {
        guard let addressSearch else {
            return
        }
        addressSuggestions = []
        addressMessage = nil
        do {
            let place = try await addressSearch.resolve(suggestion)
            latitudeText = PropertyDetailsForm.format(place.coordinate.latitude)
            longitudeText = PropertyDetailsForm.format(place.coordinate.longitude)
            addressQuery = place.name
            await deriveClimate()
        } catch {
            addressMessage = "That address didn't resolve. Enter coordinates manually."
        }
    }

    public func deriveClimate() async {
        guard let minima else {
            return
        }
        guard let coordinate = try? parsedCoordinate() else {
            return
        }
        derivationMessage = nil
        isDerivingClimate = true
        defer { isDerivingClimate = false }
        let derived: DerivedClimate
        if let cached = climateCache.cached(for: coordinate) {
            derived = cached
        } else {
            let deadline = minimaDeadline
            let series = try? await withDeadline(deadline) {
                try await minima(coordinate)
            }
            guard let series, !series.isEmpty else {
                derivationMessage =
                    "Weather history is unavailable for this location, so zone and frost "
                    + "dates were not derived. Enter them manually or try again later."
                return
            }
            let southern = coordinate.latitude < 0
            let frost = ClimateDerivation.frostDates(
                minima: series, southernHemisphere: southern)
            let zone = ClimateDerivation.estimatedZone(
                minima: series, southernHemisphere: southern)
            derived = DerivedClimate(
                zone: zone, lastFrost: frost.lastFrost, firstFrost: frost.firstFrost)
            climateCache.remember(derived, for: coordinate)
        }
        derivedClimate = derived.isEmpty ? nil : derived
        guard derivedClimate != nil else {
            derivationMessage =
                "Weather history had nothing usable for this location, so zone and frost "
                + "dates were not derived. Enter them manually."
            return
        }
        applyDerivedValues(derived)
    }

    private func applyDerivedValues(_ derived: DerivedClimate) {
        if zoneSource == .derived, let zone = derived.zone {
            zoneText = String(zone)
        }
        if frostDatesSource == .derived {
            if let last = derived.lastFrost {
                lastFrostMonth = last.month
                lastFrostDay = last.day
            }
            if let first = derived.firstFrost {
                firstFrostMonth = first.month
                firstFrostDay = first.day
            }
        }
    }
}
