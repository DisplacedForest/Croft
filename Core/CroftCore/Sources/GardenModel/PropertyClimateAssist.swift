import Domain
import Foundation

extension PropertyDetailsForm {
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
            matchConfirmation = "Matched \(place.name)"
            addressQuery = place.name
            await deriveClimate()
        } catch {
            matchConfirmation = nil
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
        isDerivingClimate = true
        defer { isDerivingClimate = false }
        let derived: DerivedClimate
        if let cached = climateCache.cached(for: coordinate) {
            derived = cached
        } else {
            guard let series = try? await minima(coordinate), !series.isEmpty else {
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
            return
        }
        offerDerivedValues(derived)
    }

    public func applySuggestion(_ field: PropertyClimateField) {
        guard let derivedClimate else {
            return
        }
        switch field {
        case .zone:
            if let zone = derivedClimate.zone {
                zoneText = String(zone)
            }
        case .lastFrost:
            if let last = derivedClimate.lastFrost {
                lastFrostMonth = last.month
                lastFrostDay = last.day
            }
        case .firstFrost:
            if let first = derivedClimate.firstFrost {
                firstFrostMonth = first.month
                firstFrostDay = first.day
            }
        }
        climateSuggestions.removeAll { $0 == field }
        derivedPrefilled.insert(field)
    }

    private func offerDerivedValues(_ derived: DerivedClimate) {
        derivedPrefilled = []
        climateSuggestions = []
        if let zone = derived.zone {
            let current = zoneText.trimmingCharacters(in: .whitespaces)
            if current.isEmpty {
                zoneText = String(zone)
                derivedPrefilled.insert(.zone)
            } else if current != String(zone) {
                climateSuggestions.append(.zone)
            }
        }
        if let last = derived.lastFrost {
            offerFrost(
                last, field: .lastFrost, month: &lastFrostMonth, day: &lastFrostDay)
        }
        if let first = derived.firstFrost {
            offerFrost(
                first, field: .firstFrost, month: &firstFrostMonth, day: &firstFrostDay)
        }
    }

    private func offerFrost(
        _ value: MonthDay,
        field: PropertyClimateField,
        month: inout Int?,
        day: inout Int?
    ) {
        if month == nil, day == nil {
            month = value.month
            day = value.day
            derivedPrefilled.insert(field)
        } else if month != value.month || day != value.day {
            climateSuggestions.append(field)
        }
    }
}
