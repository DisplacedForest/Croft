import Domain

enum SectionRoute: Hashable {
    case navigationPreview(AppSection)
    case bed(Bed.ID)
    case planting(Planting.ID)
    case plant(PlantIdentity)
}
