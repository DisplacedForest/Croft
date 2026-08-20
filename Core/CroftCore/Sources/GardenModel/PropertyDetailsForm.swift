import Foundation
import Observation
import Persistence

import enum Domain.ClimateSource
import struct Domain.GeoCoordinate
import struct Domain.HardinessZone
import struct Domain.MonthDay
import struct Domain.Property
import struct Domain.PropertyDetails
import func Domain.withDeadline

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
            "Hardiness zone must be a number from 1 to 13, optionally followed by a or b, like 8 or 8b."
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
    func updateDetails(_ id: Property.ID, _ details: PropertyDetails) throws
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

    func updateDetails(_ id: Property.ID, _ details: PropertyDetails) throws {
        try structures.updatePropertyDetails(id, details)
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
    public internal(set) var zoneSource: ClimateSource = .derived
    public internal(set) var frostDatesSource: ClimateSource = .derived
    var climateCoordinate: GeoCoordinate?
    var derivationGeneration = 0
    public private(set) var setupOutcome: PropertySetupOutcome?

    private let store: any PropertyStoring
    private let defaults: PropertySetupDefaults
    private let fillCoordinate: CoordinateFill?
    let addressSearch: (any AddressSearching)?
    private let reverseGeocode: ReverseGeocode?
    let minima: HistoricalMinima?
    let climateCache: ClimateCache
    private let geocodeDeadline: Duration
    let minimaDeadline: Duration

    public convenience init(
        database: AppDatabase,
        defaults: PropertySetupDefaults = PropertySetupDefaults(),
        fillCoordinate: CoordinateFill? = nil,
        addressSearch: (any AddressSearching)? = nil,
        reverseGeocode: ReverseGeocode? = nil,
        minima: HistoricalMinima? = nil,
        climateCache: ClimateCache = ClimateCache(),
        geocodeDeadline: Duration = .seconds(10),
        minimaDeadline: Duration = .seconds(30)
    ) {
        self.init(
            store: DatabasePropertyStore(database: database),
            defaults: defaults,
            fillCoordinate: fillCoordinate,
            addressSearch: addressSearch,
            reverseGeocode: reverseGeocode,
            minima: minima,
            climateCache: climateCache,
            geocodeDeadline: geocodeDeadline,
            minimaDeadline: minimaDeadline
        )
    }

    init(
        store: any PropertyStoring,
        defaults: PropertySetupDefaults = PropertySetupDefaults(),
        fillCoordinate: CoordinateFill? = nil,
        addressSearch: (any AddressSearching)? = nil,
        reverseGeocode: ReverseGeocode? = nil,
        minima: HistoricalMinima? = nil,
        climateCache: ClimateCache = ClimateCache(),
        geocodeDeadline: Duration = .seconds(10),
        minimaDeadline: Duration = .seconds(30)
    ) {
        self.store = store
        self.defaults = defaults
        self.fillCoordinate = fillCoordinate
        self.addressSearch = addressSearch
        self.reverseGeocode = reverseGeocode
        self.minima = minima
        self.climateCache = climateCache
        self.geocodeDeadline = geocodeDeadline
        self.minimaDeadline = minimaDeadline
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
        zoneText = property?.hardinessZone?.description ?? ""
        lastFrostMonth = property?.lastFrost?.month
        lastFrostDay = property?.lastFrost?.day
        firstFrostMonth = property?.firstFrost?.month
        firstFrostDay = property?.firstFrost?.day
        zoneSource = property?.zoneSource ?? .derived
        frostDatesSource = property?.frostDatesSource ?? .derived
        climateCoordinate = property?.location
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
            var zone = try parsedZone()
            var lastFrost = try parsedFrost(lastFrostMonth, lastFrostDay, label: "last frost")
            var firstFrost = try parsedFrost(firstFrostMonth, firstFrostDay, label: "first frost")
            dropStaleDerived(location, &zone, &lastFrost, &firstFrost)
            let home = try store.ensureHomeProperty()
            let details = PropertyDetails(
                location: location,
                hardinessZone: zone,
                lastFrost: lastFrost,
                firstFrost: firstFrost,
                zoneSource: zoneSource,
                frostDatesSource: frostDatesSource
            )
            try store.updateDetails(home.id, details)
            defaults.hasBeenPrompted = true
            setupOutcome = .saved
            var saved = home
            saved.location = location
            saved.hardinessZone = zone
            saved.lastFrost = lastFrost
            saved.firstFrost = firstFrost
            saved.zoneSource = zoneSource
            saved.frostDatesSource = frostDatesSource
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

    public func declineSetup() {
        setupOutcome = .declined
    }

    public func commitSetupOutcome() {
        guard setupOutcome != nil else {
            return
        }
        defaults.hasBeenPrompted = true
        setupOutcome = nil
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
                let deadline = geocodeDeadline
                let place = try await withDeadline(deadline) {
                    try await reverseGeocode(coordinate)
                }
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

    private func parsedZone() throws -> HardinessZone? {
        let text = zoneText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            return nil
        }
        guard let zone = HardinessZone(parsing: text) else {
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
