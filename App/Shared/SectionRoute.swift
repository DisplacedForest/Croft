import Domain

enum SectionRoute: Hashable {
    case navigationPreview(AppSection)
    case plant(PlantIdentity)
}
