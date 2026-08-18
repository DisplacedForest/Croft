import Domain

enum SectionRoute: Hashable {
    case season
    case bed(Bed.ID)
    case planting(Planting.ID)
    case plant(PlantIdentity)
}
