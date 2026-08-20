import Domain
import Foundation

enum DerivedFetch {
    case unavailable
    case empty
    case derived(DerivedClimate)
}

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

    func needsDerivationBeforeSave(_ location: GeoCoordinate?) -> Bool {
        location != climateCoordinate
            && (zoneSource == .derived || frostDatesSource == .derived)
    }

    func resolveDerivedForSave(
        _ location: GeoCoordinate?,
        _ zone: inout HardinessZone?,
        _ lastFrost: inout MonthDay?,
        _ firstFrost: inout MonthDay?
    ) async {
        guard let location, minima != nil else {
            dropStaleDerived(location, &zone, &lastFrost, &firstFrost)
            return
        }
        switch await fetchDerived(location) {
        case .derived(let derived):
            if zoneSource == .derived {
                zone = derived.zone.flatMap { HardinessZone(number: $0) }
            }
            if frostDatesSource == .derived {
                lastFrost = derived.lastFrost
                firstFrost = derived.firstFrost
            }
            if ((try? parsedCoordinate()) ?? nil) == location {
                derivedClimate = derived
                climateCoordinate = location
                applyDerivedValues(derived)
            }
        case .unavailable:
            dropUnderived(
                location, &zone, &lastFrost, &firstFrost,
                message: "Weather history is unavailable for this location, so zone and frost "
                    + "dates were not derived. Enter them manually or try again later.")
        case .empty:
            dropUnderived(
                location, &zone, &lastFrost, &firstFrost,
                message: "Weather history had nothing usable for this location, so zone and frost "
                    + "dates were not derived. Enter them manually.")
        }
    }

    private func dropUnderived(
        _ location: GeoCoordinate,
        _ zone: inout HardinessZone?,
        _ lastFrost: inout MonthDay?,
        _ firstFrost: inout MonthDay?,
        message: String
    ) {
        derivationMessage = message
        if zoneSource == .derived {
            zone = nil
        }
        if frostDatesSource == .derived {
            lastFrost = nil
            firstFrost = nil
        }
        if ((try? parsedCoordinate()) ?? nil) == location {
            derivedClimate = nil
            climateCoordinate = nil
            clearDerivedGroups()
        }
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
        guard minima != nil else {
            return
        }
        guard let coordinate = try? parsedCoordinate() else {
            return
        }
        let flight: Int
        if let derivationTask, derivationCoordinate == coordinate {
            flight = derivationFlight
            await derivationTask.value
        } else {
            derivationTask?.cancel()
            derivationFlight += 1
            flight = derivationFlight
            let task = Task { await self.performDerivation(coordinate) }
            derivationTask = task
            derivationCoordinate = coordinate
            await task.value
        }
        if derivationFlight == flight {
            derivationTask = nil
            derivationCoordinate = nil
        }
    }

    private func performDerivation(_ coordinate: GeoCoordinate) async {
        derivationMessage = nil
        isDerivingClimate = true
        defer {
            if !Task.isCancelled {
                isDerivingClimate = false
            }
        }
        let fetched = await fetchDerived(coordinate)
        guard !Task.isCancelled else {
            return
        }
        switch fetched {
        case .unavailable:
            failDerivation(
                "Weather history is unavailable for this location, so zone and frost "
                    + "dates were not derived. Enter them manually or try again later.")
        case .empty:
            failDerivation(
                "Weather history had nothing usable for this location, so zone and frost "
                    + "dates were not derived. Enter them manually.")
        case .derived(let derived):
            derivedClimate = derived
            climateCoordinate = coordinate
            applyDerivedValues(derived)
        }
    }

    func fetchDerived(_ coordinate: GeoCoordinate) async -> DerivedFetch {
        guard let minima else {
            return .unavailable
        }
        if let cached = climateCache.cached(for: coordinate) {
            return cached.isEmpty ? .empty : .derived(cached)
        }
        let deadline = minimaDeadline
        let series = try? await withDeadline(deadline) {
            try await minima(coordinate)
        }
        guard let series, !series.isEmpty else {
            return .unavailable
        }
        let southern = coordinate.latitude < 0
        let frost = ClimateDerivation.frostDates(
            minima: series, southernHemisphere: southern)
        let zone = ClimateDerivation.estimatedZone(
            minima: series, southernHemisphere: southern)
        let derived = DerivedClimate(
            zone: zone, lastFrost: frost.lastFrost, firstFrost: frost.firstFrost)
        climateCache.remember(derived, for: coordinate)
        return derived.isEmpty ? .empty : .derived(derived)
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
