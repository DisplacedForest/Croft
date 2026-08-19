import Domain
import Foundation
import GardenModel
import Persistence
import Testing

private func makeDefaults() -> PropertySetupDefaults {
    PropertySetupDefaults(
        store: UserDefaults(suiteName: "property-tests-\(UUID().uuidString)")!)
}

@MainActor
private func makeForm(
    database: AppDatabase,
    defaults: PropertySetupDefaults? = nil,
    fillCoordinate: CoordinateFill? = nil
) -> PropertyDetailsForm {
    PropertyDetailsForm(
        database: database,
        defaults: defaults ?? makeDefaults(),
        fillCoordinate: fillCoordinate
    )
}

@Test @MainActor func savingFullDetailsPersistsThem() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.latitudeText = "44.5"
    form.longitudeText = "-72.8"
    form.zoneText = "4"
    form.lastFrostMonth = 5
    form.lastFrostDay = 15
    form.firstFrostMonth = 9
    form.firstFrostDay = 28

    #expect(form.save())
    #expect(form.validationMessage == nil)

    let structures = GardenStructureRepository(database)
    let property = try #require(try structures.properties(includeArchived: true).first)
    #expect(property.location == GeoCoordinate(latitude: 44.5, longitude: -72.8))
    #expect(property.hardinessZone == HardinessZone(number: 4))
    #expect(property.lastFrost == MonthDay(month: 5, day: 15))
    #expect(property.firstFrost == MonthDay(month: 9, day: 28))
}

@Test @MainActor func savingWithNoPropertyCreatesTheHomeProperty() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    #expect(form.property == nil)
    #expect(form.save())

    let structures = GardenStructureRepository(database)
    let names = try structures.properties(includeArchived: true).map(\.name)
    #expect(names == ["Home"])
    #expect(form.property?.name == "Home")
}

@Test @MainActor func emptyFieldsSaveAsNil() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    #expect(form.save())
    let property = try #require(form.property)
    #expect(property.missingAnchors == [.location, .hardinessZone, .frostDates])
}

@Test @MainActor func unpairedCoordinateIsRejected() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.latitudeText = "44.5"
    #expect(!form.save())
    #expect(form.validationMessage == PropertyDetailsError.unpairedCoordinate.message)
}

@Test @MainActor func malformedLatitudeIsRejected() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.latitudeText = "north"
    form.longitudeText = "-72.8"
    #expect(!form.save())
    #expect(form.validationMessage == PropertyDetailsError.invalidLatitude.message)
}

@Test @MainActor func outOfRangeLongitudeIsRejected() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.latitudeText = "44.5"
    form.longitudeText = "181"
    #expect(!form.save())
    #expect(form.validationMessage == PropertyDetailsError.invalidLongitude.message)
}

@Test @MainActor func unpairedFrostDateIsRejected() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.lastFrostMonth = 5
    #expect(!form.save())
    #expect(
        form.validationMessage == PropertyDetailsError.unpairedFrostDate("last frost").message)
}

@Test @MainActor func invalidFrostDateIsRejected() throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.firstFrostMonth = 2
    form.firstFrostDay = 30
    #expect(!form.save())
    #expect(
        form.validationMessage == PropertyDetailsError.invalidFrostDate("first frost").message)
}

@Test(arguments: ["8c", "0b", "14a", "text", "b"])
@MainActor func malformedZoneIsRejected(_ text: String) throws {
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database)
    form.load()
    form.zoneText = text
    #expect(!form.save())
    #expect(form.validationMessage == PropertyDetailsError.invalidZone.message)
}

@Test(arguments: ["8", "8a", "8b"])
@MainActor func letteredZonesSaveAndRoundTrip(_ text: String) throws {
    let database = try AppDatabase.inMemory()
    let defaults = makeDefaults()
    let saving = makeForm(database: database, defaults: defaults)
    saving.load()
    saving.zoneText = text
    #expect(saving.save())
    #expect(saving.validationMessage == nil)

    let reloaded = makeForm(database: database, defaults: defaults)
    reloaded.load()
    #expect(reloaded.zoneText == text)
}

@Test @MainActor func loadRoundTripsSavedValuesIntoTheFields() throws {
    let database = try AppDatabase.inMemory()
    let defaults = makeDefaults()
    let saving = makeForm(database: database, defaults: defaults)
    saving.load()
    saving.latitudeText = "44.5"
    saving.longitudeText = "-72.8"
    saving.zoneText = "4"
    saving.lastFrostMonth = 5
    saving.lastFrostDay = 15
    #expect(saving.save())
    saving.lastFrostDay = nil
    saving.lastFrostMonth = nil
    #expect(saving.save())

    let reloaded = makeForm(database: database, defaults: defaults)
    reloaded.load()
    #expect(reloaded.latitudeText == "44.50000")
    #expect(reloaded.longitudeText == "-72.80000")
    #expect(reloaded.zoneText == "4")
    #expect(reloaded.lastFrostMonth == nil)
}

@Test @MainActor func useCurrentLocationFillsTheCoordinateFields() async throws {
    let database = try AppDatabase.inMemory()
    let coordinate = try #require(GeoCoordinate(latitude: 44.5, longitude: -72.8))
    let form = makeForm(database: database, fillCoordinate: { coordinate })
    form.load()
    await form.useCurrentLocation()
    #expect(form.latitudeText == "44.50000")
    #expect(form.longitudeText == "-72.80000")
    #expect(form.locationMessage == nil)
}

@Test @MainActor func useCurrentLocationDegradesPolitelyOnFailure() async throws {
    struct Denied: Error {}
    let database = try AppDatabase.inMemory()
    let form = makeForm(database: database, fillCoordinate: { throw Denied() })
    form.load()
    await form.useCurrentLocation()
    #expect(form.latitudeText.isEmpty)
    #expect(form.locationMessage != nil)
    #expect(form.isFillingLocation == false)
}

@Test @MainActor func setupIsOfferedOnlyUntilPromptedOrSaved() throws {
    let database = try AppDatabase.inMemory()
    let defaults = makeDefaults()

    #expect(PropertySetupGate.shouldOffer(property: nil, defaults: defaults))

    let form = makeForm(database: database, defaults: defaults)
    form.load()
    #expect(form.shouldOfferSetup)

    form.markPrompted()
    #expect(!form.shouldOfferSetup)

    let fresh = makeForm(database: database, defaults: defaults)
    fresh.load()
    #expect(!fresh.shouldOfferSetup)
}

@Test @MainActor func savingCountsAsPrompted() throws {
    let database = try AppDatabase.inMemory()
    let defaults = makeDefaults()
    let form = makeForm(database: database, defaults: defaults)
    form.load()
    #expect(form.shouldOfferSetup)
    #expect(form.save())
    #expect(!form.shouldOfferSetup)
    #expect(defaults.hasBeenPrompted)
}

@Test @MainActor func setupIsNotOfferedWhenFrostDatesExist() throws {
    let database = try AppDatabase.inMemory()
    let structures = GardenStructureRepository(database)
    let property = Property(name: "Home")
    try structures.create(property)
    try structures.updatePropertyDetails(
        property.id,
        location: nil,
        hardinessZone: nil,
        lastFrost: MonthDay(month: 5, day: 15),
        firstFrost: MonthDay(month: 9, day: 28)
    )

    let form = makeForm(database: database)
    form.load()
    #expect(!form.shouldOfferSetup)
}
