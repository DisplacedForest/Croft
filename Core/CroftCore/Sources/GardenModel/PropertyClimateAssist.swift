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
        syncDerivedGroupsToCurrentClimate()
        await deriveClimate()
    }

    public func useDerivedFrostDates() async {
        frostDatesSource = .derived
        syncDerivedGroupsToCurrentClimate()
        await deriveClimate()
    }

    func dropStaleDerived(
        _ location: GeoCoordinate?,
        _ zone: inout HardinessZone?,
        _ lastFrost: inout MonthDay?,
        _ firstFrost: inout MonthDay?
    ) {
        guard location != climateCoordinate else {
            return
        }
        if zoneSource == .derived {
            zone = nil
            zoneText = ""
        }
        if frostDatesSource == .derived {
            lastFrost = nil
            firstFrost = nil
            lastFrostMonth = nil
            lastFrostDay = nil
            firstFrostMonth = nil
            firstFrostDay = nil
        }
    }

    private func syncDerivedGroupsToCurrentClimate() {
        let current = (try? parsedCoordinate()) ?? nil
        if let derivedClimate, let climateCoordinate, climateCoordinate == current {
            applyDerivedValues(derivedClimate)
        } else {
            clearDerivedGroups()
        }
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
        derivationGeneration += 1
        let generation = derivationGeneration
        derivationMessage = nil
        isDerivingClimate = true
        defer {
            if generation == derivationGeneration {
                isDerivingClimate = false
            }
        }
        let derived: DerivedClimate
        if let cached = climateCache.cached(for: coordinate) {
            derived = cached
        } else {
            let deadline = minimaDeadline
            let series = try? await withDeadline(deadline) {
                try await minima(coordinate)
            }
            guard generation == derivationGeneration else {
                return
            }
            guard let series, !series.isEmpty else {
                failDerivation(
                    "Weather history is unavailable for this location, so zone and frost "
                        + "dates were not derived. Enter them manually or try again later.")
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
        guard derived.isEmpty == false else {
            failDerivation(
                "Weather history had nothing usable for this location, so zone and frost "
                    + "dates were not derived. Enter them manually.")
            return
        }
        derivedClimate = derived
        climateCoordinate = coordinate
        applyDerivedValues(derived)
    }

    private func failDerivation(_ message: String) {
        derivationMessage = message
        derivedClimate = nil
        climateCoordinate = nil
        clearDerivedGroups()
    }

    private func clearDerivedGroups() {
        if zoneSource == .derived {
            zoneText = ""
        }
        if frostDatesSource == .derived {
            lastFrostMonth = nil
            lastFrostDay = nil
            firstFrostMonth = nil
            firstFrostDay = nil
        }
    }

    private func applyDerivedValues(_ derived: DerivedClimate) {
        if zoneSource == .derived {
            zoneText = derived.zone.map(String.init) ?? ""
        }
        if frostDatesSource == .derived {
            lastFrostMonth = derived.lastFrost?.month
            lastFrostDay = derived.lastFrost?.day
            firstFrostMonth = derived.firstFrost?.month
            firstFrostDay = derived.firstFrost?.day
        }
    }
}
