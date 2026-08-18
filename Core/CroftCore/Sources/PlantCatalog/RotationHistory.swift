import Domain
import Foundation
import Persistence

public struct FamilyOccupancy: Equatable, Sendable {
    public let familyName: String
    public let mostRecentYear: Int

    public init(familyName: String, mostRecentYear: Int) {
        self.familyName = familyName
        self.mostRecentYear = mostRecentYear
    }
}

public struct RotationWarning: Equatable, Sendable {
    public let familyName: String
    public let year: Int

    public init(familyName: String, year: Int) {
        self.familyName = familyName
        self.year = year
    }
}

public struct RotationHistory: Sendable {
    public static let lookbackYears = 3
    public static let historyLineCap = 3

    private let knowledgeSpecies: SpeciesRepository
    private let knowledgeCultivars: CultivarRepository
    private let knowledgeGenera: GenusRepository
    private let knowledgeFamilies: PlantFamilyRepository
    private let personalSpecies: SpeciesRepository
    private let personalCultivars: CultivarRepository
    private let personalGenera: GenusRepository
    private let personalFamilies: PlantFamilyRepository
    private let plantings: PlantingRepository

    public init(knowledge: AppDatabase, personal: AppDatabase) {
        knowledgeSpecies = SpeciesRepository(knowledge)
        knowledgeCultivars = CultivarRepository(knowledge)
        knowledgeGenera = GenusRepository(knowledge)
        knowledgeFamilies = PlantFamilyRepository(knowledge)
        personalSpecies = SpeciesRepository(personal)
        personalCultivars = CultivarRepository(personal)
        personalGenera = GenusRepository(personal)
        personalFamilies = PlantFamilyRepository(personal)
        plantings = PlantingRepository(personal)
    }

    public init(_ database: AppDatabase) {
        self.init(knowledge: database, personal: database)
    }

    public func warning(
        for candidate: PlantIdentity,
        inBed bedID: Bed.ID,
        on reference: Date = Date(),
        calendar: Calendar = Calendar.current
    ) throws -> RotationWarning? {
        guard let candidateFamily = try familyName(of: candidate) else {
            return nil
        }
        let priors = try priorFamilyYears(inBed: bedID, on: reference, calendar: calendar)
        guard let year = priors[candidateFamily] else {
            return nil
        }
        return RotationWarning(familyName: candidateFamily, year: year)
    }

    public func historyLines(
        inBed bedID: Bed.ID,
        on reference: Date = Date(),
        calendar: Calendar = Calendar.current
    ) throws -> [FamilyOccupancy] {
        let priors = try priorFamilyYears(inBed: bedID, on: reference, calendar: calendar)
        var lines = priors.map { entry in
            FamilyOccupancy(familyName: entry.key, mostRecentYear: entry.value)
        }
        lines.sort { first, second in
            if first.mostRecentYear == second.mostRecentYear {
                return first.familyName < second.familyName
            }
            return first.mostRecentYear > second.mostRecentYear
        }
        return Array(lines.prefix(RotationHistory.historyLineCap))
    }

    private func priorFamilyYears(
        inBed bedID: Bed.ID,
        on reference: Date,
        calendar: Calendar
    ) throws -> [String: Int] {
        let currentYear = calendar.component(.year, from: reference)
        let windowStart = currentYear - RotationHistory.lookbackYears
        var mostRecent: [String: Int] = [:]
        for planting in try plantings.plantings(inBed: bedID) {
            guard let plantedOn = planting.plantedOn else {
                continue
            }
            guard let family = try familyName(of: planting.identity) else {
                continue
            }
            let plantedYear = calendar.component(.year, from: plantedOn)
            let endYear =
                planting.endedOn.map { calendar.component(.year, from: $0) } ?? currentYear
            let lastPriorYear = min(endYear, currentYear - 1)
            guard lastPriorYear >= plantedYear, lastPriorYear >= windowStart else {
                continue
            }
            mostRecent[family] = max(mostRecent[family] ?? .min, lastPriorYear)
        }
        return mostRecent
    }

    private func familyName(of identity: PlantIdentity) throws -> String? {
        let speciesID: Species.ID?
        switch identity {
        case .species(let id):
            speciesID = id
        case .cultivar(let id):
            let cultivar =
                try knowledgeCultivars.fetch(id: id) ?? personalCultivars.fetch(id: id)
            speciesID = cultivar?.speciesID
        }
        guard let speciesID else {
            return nil
        }
        guard
            let species = try knowledgeSpecies.fetch(id: speciesID)
                ?? personalSpecies.fetch(id: speciesID)
        else {
            return nil
        }
        guard
            let genus = try knowledgeGenera.fetch(id: species.genusID)
                ?? personalGenera.fetch(id: species.genusID)
        else {
            return nil
        }
        let family =
            try knowledgeFamilies.fetch(id: genus.familyID)
            ?? personalFamilies.fetch(id: genus.familyID)
        return family?.name
    }
}
