import enum Domain.ObservationTarget

enum CaptureTargetResolver {
    static func target(for route: SectionRoute?) -> ObservationTarget? {
        switch route {
        case .planting(let id):
            .planting(id)
        case .bed(let id):
            .bed(id)
        case .plant(let identity):
            .plant(identity)
        case .crop(let speciesID):
            .plant(.species(speciesID))
        case .season, nil:
            nil
        }
    }
}
