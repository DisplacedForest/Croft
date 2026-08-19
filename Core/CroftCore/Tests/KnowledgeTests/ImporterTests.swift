import Domain
import Foundation
import GRDB
import Graph
import Persistence
import Testing

@testable import Knowledge

struct ImporterIntegrityTests {
    @Test func aChecksumMismatchIsRejectedWithTheOffendingFile() throws {
        let fixture = try KnowledgeFixture(
            pinnedOverrides: [KnowledgeImporter.cropProfilesFile: String(repeating: "0", count: 64)]
        )
        #expect {
            try fixture.build()
        } throws: { error in
            guard case .checksumMismatch(let file, _, _) = error as? ImportError else {
                return false
            }
            return file == KnowledgeImporter.cropProfilesFile
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.output.path))
    }

    @Test func aMissingLockFileIsRejected() throws {
        let fixture = try KnowledgeFixture()
        try FileManager.default.removeItem(
            at: fixture.directory.appendingPathComponent(InputsLock.fileName))
        #expect(throws: ImportError.missingInput(InputsLock.fileName)) {
            try fixture.build()
        }
    }

    @Test func anUnknownPestHostFailsTheImport() throws {
        let fixture = try KnowledgeFixture(
            pestDisease: KnowledgeFixture.pestDisease.replacingOccurrences(
                of: "\"hosts\": [\"tomato\"],\n      \"biology\"",
                with: "\"hosts\": [\"kudzu\"],\n      \"biology\""
            ))
        #expect(throws: ImportError.unknownCrop(record: "tomato-hornworm", crop: "kudzu")) {
            try fixture.build()
        }
    }

    @Test func anUnknownVectorTargetFailsTheImport() throws {
        let fixture = try KnowledgeFixture(
            pestDisease: KnowledgeFixture.pestDisease.replacingOccurrences(
                of: "\"vector_of\": [\"mosaic-virus\"]",
                with: "\"vector_of\": [\"tulip-mania\"]"
            ))
        #expect(
            throws: ImportError.unknownReference(
                record: "green-peach-aphid", reference: "tulip-mania")
        ) {
            try fixture.build()
        }
    }

    @Test func anUnknownPathogenTypeFailsTheImport() throws {
        let fixture = try KnowledgeFixture(
            pestDisease: KnowledgeFixture.pestDisease.replacingOccurrences(
                of: "\"pathogen_type\": \"virus\"",
                with: "\"pathogen_type\": \"miasma\""
            ))
        #expect(
            throws: ImportError.unmappableValue(
                record: "mosaic-virus", field: "pathogen_type", value: "miasma")
        ) {
            try fixture.build()
        }
    }

    @Test func anUnknownResistanceTargetFailsTheImport() throws {
        let fixture = try KnowledgeFixture(
            pestDisease: KnowledgeFixture.pestDisease.replacingOccurrences(
                of: "\"resistances\": [\"tomato-hornworm\"]",
                with: "\"resistances\": [\"bad-vibes\"]"
            ))
        #expect(
            throws: ImportError.unknownReference(record: "Brandywine", reference: "bad-vibes")
        ) {
            try fixture.build()
        }
    }

    @Test func aFailedImportLeavesNoSnapshotBehind() throws {
        let fixture = try KnowledgeFixture(
            pestDisease: KnowledgeFixture.pestDisease.replacingOccurrences(
                of: "\"pathogen_type\": \"virus\"",
                with: "\"pathogen_type\": \"miasma\""
            ))
        #expect(throws: ImportError.self) {
            try fixture.build()
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.output.path))
    }
}

struct ImporterMappingTests {
    @Test func doubledRunsProduceIdenticalLogicalContent() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let first = try KnowledgeSnapshot.logicalDump(at: fixture.output)
        try fixture.build()
        let second = try KnowledgeSnapshot.logicalDump(at: fixture.output)
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test func theSummaryCountsThePolicySkips() throws {
        let fixture = try KnowledgeFixture()
        let summary = try fixture.build()
        #expect(summary.skips["catalog_ambiguous_squash"] == 1)
        #expect(summary.skips["catalog_gourd_out_of_scope"] == 1)
        #expect(summary.skips["catalog_out_of_scope_crop"] == 1)
        #expect(summary.skips["catalog_unmapped_growth_habit"] == 1)
        #expect(summary.skips["catalog_unparsed_spacing"] == 1)
        #expect(summary.skips["resistance_ambiguous_squash"] == 1)
        #expect(summary.normalizations["disease_pathogen_type_normalized"] == 1)
        #expect(summary.counts["species"] == 3)
        #expect(summary.counts["pests"] == 2)
        #expect(summary.counts["diseases"] == 3)
    }

    @Test func squashCatalogRowsClassifyToTheSplitCrops() throws {
        let fixture = try KnowledgeFixture()
        _ = try fixture.build()
        let dump = try KnowledgeSnapshot.logicalDump(at: fixture.output)
        #expect(dump.contains("cultivar:cucurbita-pepo/golden-zucchini"))
        #expect(dump.contains("cultivar:cucurbita-maxima/butternut-ultra"))
        #expect(!dump.contains("birdhouse-gourd"))
        #expect(!dump.contains("marrow-mystery"))
        #expect(!dump.contains("ultra-nova"))
    }

    @Test func vendorsMergeIntoOneCultivarWithThePreferredFields() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let cultivars = CultivarRepository(database)
        let brandywine = try #require(
            try cultivars.fetch(
                id: Cultivar.ID(rawValue: "cultivar:solanum-lycopersicum/brandywine")))
        #expect(brandywine.daysToMaturity == 80...80)
        #expect(brandywine.spacingCentimeters == 45.7...91.4)
        #expect(brandywine.growthHabit == .vine)
        #expect(brandywine.heirloom == true)
        #expect(brandywine.seedTypes == [.heirloom, .openPollinated])
        #expect(brandywine.seedPreps == [.soaking])
    }

    @Test func anExplicitHeirloomFalseDropsTheConflictingTag() throws {
        let fixture = try KnowledgeFixture()
        let summary = try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let cultivars = CultivarRepository(database)
        let sungold = try #require(
            try cultivars.fetch(
                id: Cultivar.ID(rawValue: "cultivar:solanum-lycopersicum/sungold-select")))
        #expect(sungold.heirloom == false)
        #expect(sungold.seedTypes == [.hybrid])
        #expect(summary.normalizations["catalog_heirloom_tag_dropped"] == 1)
    }

    @Test func speciesCarryConvertedMetricUnits() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let species = SpeciesRepository(database)
        let tomato = try #require(
            try species.fetch(id: Species.ID(rawValue: "species:solanum-lycopersicum")))
        #expect(tomato.germinationTempMin == 10)
        #expect(tomato.germinationTempOptimal == 18.3...29.4)
        #expect(tomato.germinationTempMax == 35)
        #expect(tomato.transplantSoilTempMin == 15.6)
        #expect(tomato.sowingDepthCentimeters == 0.6...0.6)
        #expect(tomato.spacingCentimeters == 45.7...91.4)
        #expect(tomato.rowSpacingCentimeters == 91.4...152.4)
        #expect(tomato.daysToMaturity == 60...90)
        #expect(tomato.soilPH == 6.0...6.8)
        #expect(tomato.sowingMethod == .transplant)
        #expect(tomato.frostTolerance == .tender)
        #expect(tomato.daysToMaturityBasis == .fromTransplant)
        #expect(tomato.lifeCycle == .annual)
        #expect(tomato.sunExposure == .fullSun)
    }

    @Test func proseFieldsDegradeToNilNotGarbage() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let species = SpeciesRepository(database)
        let winter = try #require(
            try species.fetch(id: Species.ID(rawValue: "species:cucurbita-maxima")))
        #expect(winter.daysToMaturity == nil)
        #expect(winter.sowingDepthCentimeters == nil)
        #expect(winter.lifeCycle == .perennial)
        #expect(winter.sowingMethod == .plantingStock)
        #expect(winter.daysToMaturityBasis == .fromPlantingStock)
    }

    @Test func squashHostsFanOutToBothSquashSpecies() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let hosts = try database.writer.read { db in
            try GraphStore.incoming(to: "pest:green-peach-aphid", via: .hostOf, in: db)
                .map(\.source.id)
        }
        #expect(
            hosts == [
                "species:cucurbita-maxima", "species:cucurbita-pepo",
                "species:solanum-lycopersicum",
            ])
    }

    @Test func resistanceExamplesCreateCultivarsAndTypedEdges() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let cultivars = CultivarRepository(database)
        let ironLady = try #require(
            try cultivars.fetch(
                id: Cultivar.ID(rawValue: "cultivar:solanum-lycopersicum/iron-lady")))
        #expect(ironLady.daysToMaturity == 75...75)
        let edges = try database.writer.read { db in
            try GraphStore.outgoing(
                from: "cultivar:solanum-lycopersicum/iron-lady", via: .resistantTo, in: db)
        }
        #expect(edges.map(\.target.id) == ["disease:early-blight"])
        #expect(edges.first?.provenance.source == "fixture verification note")
        #expect(edges.first?.provenance.sourceType == .reference)
        #expect(edges.first?.provenance.notes == "EB (HR)")
    }

    @Test func aResistanceTargetMayBeAPest() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let edges = try database.writer.read { db in
            try GraphStore.outgoing(
                from: "cultivar:solanum-lycopersicum/brandywine", via: .resistantTo, in: db)
        }
        #expect(edges.map(\.target) == [EntityRef(id: "pest:tomato-hornworm", type: .pest)])
    }

    @Test func vectorEdgesComeFromBothDirectionsWithoutDuplicates() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let edges = try database.writer.read { db in
            try GraphStore.outgoing(from: "pest:green-peach-aphid", via: .vectorOf, in: db)
        }
        #expect(edges.map(\.target.id) == ["disease:mosaic-virus"])
    }

    @Test func diseasesLinkToTheirPathogens() throws {
        let fixture = try KnowledgeFixture()
        try fixture.build()
        let database = try AppDatabase.openReadOnly(at: fixture.output)
        let edges = try database.writer.read { db in
            try GraphStore.outgoing(from: "disease:early-blight", via: .causedBy, in: db)
        }
        #expect(edges.map(\.target.id) == ["pathogen:alternaria-solani"])
        let diseases = DiseaseRepository(database)
        let clubroot = try #require(
            try diseases.fetch(id: Disease.ID(rawValue: "disease:clubroot")))
        #expect(clubroot.pathogenType == .protist)
    }
}
