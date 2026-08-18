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

@MainActor
@Observable
public final class PropertyDetailsForm {
    public private(set) var property: Property?
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

    private let editor: GardenEditor
    private let structures: GardenStructureRepository
    private let defaults: PropertySetupDefaults
    private let fillCoordinate: CoordinateFill?

    public init(
        database: AppDatabase,
        defaults: PropertySetupDefaults = PropertySetupDefaults(),
        fillCoordinate: CoordinateFill? = nil
    ) {
        editor = GardenEditor(database)
        structures = GardenStructureRepository(database)
        self.defaults = defaults
        self.fillCoordinate = fillCoordinate
    }

    public var canFillLocation: Bool {
        fillCoordinate != nil
    }

    public var shouldOfferSetup: Bool {
        PropertySetupGate.shouldOffer(property: property, defaults: defaults)
    }

    public func load() {
        property = (try? structures.properties(includeArchived: true))?.first
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
        do {
            let location = try parsedCoordinate()
            let zone = try parsedZone()
            let lastFrost = try parsedFrost(lastFrostMonth, lastFrostDay, label: "last frost")
            let firstFrost = try parsedFrost(firstFrostMonth, firstFrostDay, label: "first frost")
            let home = try editor.homeProperty()
            try structures.updatePropertyDetails(
                home.id,
                location: location,
                hardinessZone: zone,
                lastFrost: lastFrost,
                firstFrost: firstFrost
            )
            defaults.hasBeenPrompted = true
            property = try structures.property(id: home.id)
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
        do {
            let coordinate = try await fillCoordinate()
            latitudeText = Self.format(coordinate.latitude)
            longitudeText = Self.format(coordinate.longitude)
        } catch {
            locationMessage =
                "Location is unavailable. Allow location access in System Settings or enter coordinates manually."
        }
    }

    private func parsedCoordinate() throws -> GeoCoordinate? {
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

    private static func format(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}
