import Domain
import Foundation
import Graph
import Persistence
import PlantCatalog
import Testing

@Suite struct PlantPageLoaderTests {
    @Test func speciesPageAssemblesTaxonomyAndConditions() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.displayName == "Tomato")
        #expect(page.commonNames == ["Tomato", "Love Apple"])
        #expect(page.taxonomy.familyName == "Solanaceae")
        #expect(page.taxonomy.genusName == "Solanum")
        #expect(page.taxonomy.scientificName == "Solanum lycopersicum")
        #expect(page.taxonomy.cultivarName == nil)
        #expect(page.conditions.sunExposure == .fullSun)
        #expect(page.conditions.waterNeed == .moderate)
        #expect(page.conditions.soilPH == 6.0...6.8)
        #expect(page.conditions.daysToMaturity == PlantAttribute(value: 60...85))
        #expect(page.conditions.spacingCentimeters == PlantAttribute(value: 45.0...60.0))
        #expect(page.conditions.harvestableParts == [.fruit])
    }

    @Test func cultivarPageAppliesOverridesAndInheritsTheRest() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        #expect(page.displayName == "Brandywine")
        #expect(page.taxonomy.cultivarName == "Brandywine")
        #expect(page.taxonomy.scientificName == "Solanum lycopersicum")
        #expect(
            page.conditions.daysToMaturity
                == PlantAttribute(value: 85...100, isCultivarOverride: true))
        #expect(page.conditions.spacingCentimeters == PlantAttribute(value: 45.0...60.0))
        #expect(page.conditions.sunExposure == .fullSun)
        #expect(page.conditions.frostTolerance == .tender)
    }

    @Test func threatsComeFromPestAndDiseaseEdges() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.threats.map(\.name) == ["Early Blight", "Tomato Hornworm"])
        let blight = try #require(page.threats.first)
        #expect(blight.kind == .disease)
        #expect(blight.agentName == "Alternaria solani")
        #expect(blight.summary == "Concentric leaf spots and stem lesions")
        let pest = try #require(page.threats.last)
        #expect(pest.kind == .pest)
        #expect(pest.summary == "Defoliation and scarred fruit")
        #expect(pest.affectedParts == [.leaf, .fruit])
    }

    @Test func cultivarInheritsSpeciesThreatsWithoutDuplicates() throws {
        let fixture = try CatalogFixture()
        try fixture.relate(
            fixture.plantRef(brandywine.id.rawValue), .susceptibleTo,
            EntityRef(id: earlyBlight.id.rawValue, type: .disease))
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        #expect(page.threats.map(\.name) == ["Early Blight", "Tomato Hornworm"])
    }

    @Test func beneficialOrganismsAreNotThreats() throws {
        let fixture = try CatalogFixture()
        try fixture.relate(
            fixture.plantRef(tomato.id.rawValue), .hostOf,
            EntityRef(id: ladybird.id.rawValue, type: .pest))
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(!page.threats.map(\.name).contains("Ladybird Beetle"))
    }

    @Test func currentPlantingsCarryLocationAndCount() throws {
        let fixture = try CatalogFixture()
        try fixture.plantings.insert(
            Planting(
                identity: .cultivar(brandywine.id),
                bedID: longBed.id,
                plantedOn: CatalogFixture.plantingDate,
                quantity: 6,
                status: .active
            ))
        try fixture.plantings.insert(
            Planting(
                identity: .cultivar(brandywine.id),
                bedID: tunnelBed.id,
                plantedOn: CatalogFixture.plantingDate,
                status: .finished,
                endedOn: CatalogFixture.endDate
            ))
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        #expect(page.currentPlantings.count == 1)
        let current = try #require(page.currentPlantings.first)
        #expect(current.locationName == "Long Bed, Kitchen Garden")
        #expect(current.quantity == 6)
        #expect(current.status == .active)
    }

    @Test func speciesPageIncludesCultivarPlantings() throws {
        let fixture = try CatalogFixture()
        try fixture.plantings.insert(
            Planting(
                identity: .cultivar(brandywine.id),
                bedID: longBed.id,
                quantity: 3,
                status: .active
            ))
        try fixture.plantings.insert(
            Planting(
                identity: .species(tomato.id),
                bedID: tunnelBed.id,
                quantity: 2,
                status: .planned
            ))
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.currentPlantings.count == 2)
        #expect(
            Set(page.currentPlantings.compactMap(\.locationName))
                == ["Long Bed, Kitchen Garden", "Tunnel Bed, Polytunnel"])
    }

    @Test func activityDerivesFromPlantingEventsNewestFirst() throws {
        let fixture = try CatalogFixture()
        try fixture.plantings.insert(
            Planting(
                identity: .cultivar(brandywine.id),
                bedID: longBed.id,
                plantedOn: CatalogFixture.plantingDate,
                transplantedOn: CatalogFixture.transplantDate,
                quantity: 6,
                status: .finished,
                endedOn: CatalogFixture.endDate
            ))
        let page = try #require(try fixture.loader.page(for: .cultivar(brandywine.id)))
        #expect(page.activity.map(\.kind) == [.finished, .transplanted, .planted])
        #expect(
            page.activity.map(\.date) == [
                CatalogFixture.endDate, CatalogFixture.transplantDate, CatalogFixture.plantingDate,
            ])
        #expect(page.activity.allSatisfy { $0.locationName == "Long Bed, Kitchen Garden" })
    }

    @Test func knowledgeOnlyPageStillRenders() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(basil.id)))
        #expect(page.displayName == "Basil")
        #expect(page.taxonomy.familyName == "Lamiaceae")
        #expect(page.conditions.sunExposure == .fullSun)
        #expect(page.threats.isEmpty)
        #expect(page.currentPlantings.isEmpty)
        #expect(page.activity.isEmpty)
    }

    @Test func personalDataReadsFromASeparateDatabase() throws {
        let fixture = try CatalogFixture()
        let personal = try AppDatabase.inMemory()
        try PlantFamilyRepository(personal).insert(solanaceae)
        try GenusRepository(personal).insert(solanum)
        try SpeciesRepository(personal).insert(tomato)
        try CultivarRepository(personal).insert(brandywine)
        let structures = GardenStructureRepository(personal)
        try structures.create(homeProperty)
        try structures.create(kitchenGarden, in: homeProperty.id)
        try structures.create(longBed, in: .garden(kitchenGarden.id))
        try PlantingRepository(personal).insert(
            Planting(
                identity: .cultivar(brandywine.id),
                bedID: longBed.id,
                quantity: 4,
                status: .active
            ))
        let loader = PlantPageLoader(knowledge: fixture.database, personal: personal)
        let page = try #require(try loader.page(for: .cultivar(brandywine.id)))
        #expect(page.threats.map(\.name) == ["Early Blight", "Tomato Hornworm"])
        #expect(page.currentPlantings.count == 1)
        #expect(page.currentPlantings.first?.locationName == "Long Bed, Kitchen Garden")
        #expect(page.currentPlantings.first?.quantity == 4)
    }

    @Test func unknownPlantReturnsNil() throws {
        let fixture = try CatalogFixture()
        #expect(try fixture.loader.page(for: .species(Species.ID.generate())) == nil)
    }
}
