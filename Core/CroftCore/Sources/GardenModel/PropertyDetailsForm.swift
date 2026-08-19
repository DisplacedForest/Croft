import Foundation
import Observation
import Persistence

import struct Domain.GeoCoordinate
import struct Domain.MonthDay
import struct Domain.Property

public typealias CoordinateFill = @Sendable () async throws -> GeoCoordinate

public enum PropertyDetailsError: Error, Equatable {
    case unpairedCoordinate
    case invalidLatitude
    case invalidLongitude
    case unpairedFrostDate(String)
    case invalidFrostDate(String)
    case invalidZone

    public var message: String {
        switch self {
        case .unpairedCoordinate:
            "Enter both latitude and longitude, or leave both empty."
        case .invalidLatitude:
            "Latitude must be a number between -90 and 90."
        case .invalidLongitude:
            "Longitude must be a number between -180 and 180."
        case .unpairedFrostDate(let label):
            "Pick both a month and a day for the \(label) date, or clear both."
        case .invalidFrostDate(let label):
            "The \(label) date is not a valid month and day."
        case .invalidZone:
            "Hardiness zone must be a whole number."
        }
    }
}

public enum PropertySourceState: Equatable, Sendable {
    case missing
    case loaded
    case unreadable
}

@MainActor
protocol PropertyStoring {
    func firstProperty() throws -> Property?
    func ensureHomeProperty() throws -> Property
    func updateDetails(
        _ id: Property.ID,
        location: GeoCoordinate?,
        hardinessZone: Int?,
        lastFrost: MonthDay?,
        firstFrost: MonthDay?
    ) throws
}

@MainActor
private struct DatabasePropertyStore: PropertyStoring {
    let editor: GardenEditor
    let structures: GardenStructureRepository

    init(database: AppDatabase) {
        editor = GardenEditor(database)
        structures = GardenStructureRepository(database)
    }

    func firstProperty() throws -> Property? {
        try structures.properties(includeArchived: true).first
    }

    func ensureHomeProperty() throws -> Property {
        try editor.homeProperty()
    }

    func updateDetails(
        _ id: Property.ID,
        location: GeoCoordinate?,
        hardinessZone: Int?,
        lastFrost: MonthDay?,
        firstFrost: MonthDay?
    ) throws {
        try structures.updatePropertyDetails(
            id,
            location: location,
            hardinessZone: hardinessZone,
            lastFrost: lastFrost,
            firstFrost: firstFrost
        )
    }
}

@MainActor
@Observable
public final class PropertyDetailsForm {
    public private(set) var property: Property?
    public private(set) var sourceState: PropertySourceState = .missing
    public private(set) var loadFailureMessage: String?
    public var latitudeText = ""
    public var longitudeText = ""
    public var zoneText = ""
    public var lastFrostMonth: Int?
    public var lastFrostDay: Int?
    public var firstFrostMonth: Int?
    public var firstFrostDay: Int?
    public private(set) var validationMessage: String?
    public private(set) var locationMessage: String?
    public private(set) var isFillingLocation = false
    public var addressQuery = ""
    public internal(set) var addressSuggestions: [AddressSuggestion] = []
    public internal(set) var addressMessage: String?
    public internal(set) var isDerivingClimate = false
    public internal(set) var derivationMessage: String?
    public internal(set) var derivedClimate: DerivedClimate?
    public internal(set) var derivedPrefilled: Set<PropertyClimateField> = []
    public internal(set) var climateSuggestions: [PropertyClimateField] = []

    private let store: any PropertyStoring
    private let defaults: PropertySetupDefaults
    private let fillCoordinate: CoordinateFill?
    let addressSearch: (any AddressSearching)?
    private let reverseGeocode: ReverseGeocode?
    let minima: HistoricalMinima?
    let climateCache: ClimateCache

    public convenience init(
        database: AppDatabase,
        defaults: PropertySetupDefaults = PropertySetupDefaults(),
        fillCoordinate: CoordinateFill? = nil,
        addressSearch: (any AddressSearching)? = nil,
        reverseGeocode: ReverseGeocode? = nil,
        minima: HistoricalMinima? = nil,
        climateCache: ClimateCache = ClimateCache()
    ) {
        self.init(
            store: DatabasePropertyStore(database: database),
            defaults: defaults,
            fillCoordinate: fillCoordinate,
            addressSearch: addressSearch,
            reverseGeocode: reverseGeocode,
            minima: minima,
            climateCache: climateCache
        )
    }

    init(
        store: any PropertyStoring,
        defaults: PropertySetupDefaults = PropertySetupDefaults(),
        fillCoordinate: CoordinateFill? = nil,
        addressSearch: (any AddressSearching)? = nil,
        reverseGeocode: ReverseGeocode? = nil,
        minima: HistoricalMinima? = nil,
        climateCache: ClimateCache = ClimateCache()
    ) {
        self.store = store
        self.defaults = defaults
        self.fillCoordinate = fillCoordinate
        self.addressSearch = addressSearch
        self.reverseGeocode = reverseGeocode
        self.minima = minima
        self.climateCache = climateCache
    }

    public var canFillLocation: Bool {
        fillCoordinate != nil
    }

    public var shouldOfferSetup: Bool {
        guard sourceState != .unreadable else {
            return false
        }
        return PropertySetupGate.shouldOffer(property: property, defaults: defaults)
    }

    public func load() {
        do {
            property = try store.firstProperty()
            sourceState = property == nil ? .missing : .loaded
            loadFailureMessage = nil
        } catch {
            property = nil
            sourceState = .unreadable
            loadFailureMessage =
                "Croft can't read the saved property details. The stored record has been "
                + "left untouched; back up your garden database file before changing anything."
        }
        latitudeText = property?.location.map { Self.format($0.latitude) } ?? ""
        longitudeText = property?.location.map { Self.format($0.longitude) } ?? ""
        zoneText = property?.hardinessZone.map(String.init) ?? ""
        lastFrostMonth = property?.lastFrost?.month
        lastFrostDay = property?.lastFrost?.day
        firstFrostMonth = property?.firstFrost?.month
        firstFrostDay = property?.firstFrost?.day
        validationMessage = nil
        locationMessage = nil
    }

    @discardableResult
    public func save() -> Bool {
        validationMessage = nil
        guard sourceState != .unreadable else {
            validationMessage = "The property record can't be read, so saving is disabled."
            return false
        }
        do {
            let location = try parsedCoordinate()
            let zone = try parsedZone()
            let lastFrost = try parsedFrost(lastFrostMonth, lastFrostDay, label: "last frost")
            let firstFrost = try parsedFrost(firstFrostMonth, firstFrostDay, label: "first frost")
            let home = try store.ensureHomeProperty()
            try store.updateDetails(
                home.id,
                location: location,
                hardinessZone: zone,
                lastFrost: lastFrost,
                firstFrost: firstFrost
            )
            defaults.hasBeenPrompted = true
            var saved = home
            saved.location = location
            saved.hardinessZone = zone
            saved.lastFrost = lastFrost
            saved.firstFrost = firstFrost
            property = saved
            sourceState = .loaded
            return true
        } catch let error as PropertyDetailsError {
            validationMessage = error.message
            return false
        } catch {
            validationMessage = "Could not save the property details."
            return false
        }
    }

    public func markPrompted() {
        defaults.hasBeenPrompted = true
    }

    public func useCurrentLocation() async {
        guard let fillCoordinate else {
            return
        }
        locationMessage = nil
        isFillingLocation = true
        defer { isFillingLocation = false }
        let coordinate: GeoCoordinate
        do {
            coordinate = try await fillCoordinate()
        } catch {
            locationMessage =
                "Location is unavailable. Allow location access in System Settings or enter coordinates manually."
            return
        }
        latitudeText = Self.format(coordinate.latitude)
        longitudeText = Self.format(coordinate.longitude)
        if let reverseGeocode {
            addressMessage = nil
            do {
                let place = try await reverseGeocode(coordinate)
                addressQuery = place.name
                addressSuggestions = []
            } catch {
                addressMessage =
                    "No address was found for this spot, so it stays as coordinates."
            }
        }
        await deriveClimate()
    }

    func parsedCoordinate() throws -> GeoCoordinate? {
        let latText = latitudeText.trimmingCharacters(in: .whitespaces)
        let lonText = longitudeText.trimmingCharacters(in: .whitespaces)
        if latText.isEmpty, lonText.isEmpty {
            return nil
        }
        guard !latText.isEmpty, !lonText.isEmpty else {
            throw PropertyDetailsError.unpairedCoordinate
        }
        guard let latitude = Double(latText), (-90.0...90.0).contains(latitude) else {
            throw PropertyDetailsError.invalidLatitude
        }
        guard let longitude = Double(lonText), (-180.0...180.0).contains(longitude) else {
            throw PropertyDetailsError.invalidLongitude
        }
        guard let coordinate = GeoCoordinate(latitude: latitude, longitude: longitude) else {
            throw PropertyDetailsError.unpairedCoordinate
        }
        return coordinate
    }

    private func parsedZone() throws -> Int? {
        let text = zoneText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            return nil
        }
        guard let zone = Int(text) else {
            throw PropertyDetailsError.invalidZone
        }
        return zone
    }

    private func parsedFrost(_ month: Int?, _ day: Int?, label: String) throws -> MonthDay? {
        switch (month, day) {
        case (nil, nil):
            return nil
        case (let month?, let day?):
            guard let monthDay = MonthDay(month: month, day: day) else {
                throw PropertyDetailsError.invalidFrostDate(label)
            }
            return monthDay
        default:
            throw PropertyDetailsError.unpairedFrostDate(label)
        }
    }

    static func format(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}
