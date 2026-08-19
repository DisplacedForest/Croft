import Domain

enum SectionRoute: Hashable {
    case bed(Bed.ID)
    case planting(Planting.ID)
    case plant(PlantIdentity)
    case crop(Species.ID)
    case season
}
