import Domain
import PlantCatalog
import Testing

@Suite struct PlantPageStructureTests {
    @Test func threatsPartitionIntoPestsAndDiseases() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        #expect(page.pests.map(\.name) == ["Tomato Hornworm"])
        #expect(page.diseases.map(\.name) == ["Early Blight"])
        #expect(page.pests.count + page.diseases.count == page.threats.count)
    }

    @Test func personalSectionsPrecedeThreatSections() throws {
        let order = PlantPage.sectionOrder
        let growingNow = try #require(order.firstIndex(of: .growingNow))
        let activity = try #require(order.firstIndex(of: .recentActivity))
        let pests = try #require(order.firstIndex(of: .pests))
        let diseases = try #require(order.firstIndex(of: .diseases))
        #expect(growingNow < pests)
        #expect(growingNow < diseases)
        #expect(activity < pests)
        #expect(activity < diseases)
        #expect(order.firstIndex(of: .conditions) == 0)
        #expect(Set(order) == Set(PlantPageSectionKind.allCases))
    }

    @Test func partitionedThreatsKeepDetailContent() throws {
        let fixture = try CatalogFixture()
        let page = try #require(try fixture.loader.page(for: .species(tomato.id)))
        let pest = try #require(page.pests.first)
        #expect(pest.agentName == "Manduca quinquemaculata")
        #expect(pest.summary == "Defoliation and scarred fruit")
        #expect(pest.affectedParts == [.leaf, .fruit])
        let disease = try #require(page.diseases.first)
        #expect(disease.agentName == "Alternaria solani")
        #expect(disease.summary == "Concentric leaf spots and stem lesions")
    }
}
