import SwiftUI

public enum DesignResources {
    public static let bundle = Bundle.module
}

extension Color {
    public static let domainGarden = Color("DomainGarden", bundle: .module)
    public static let domainAnimals = Color("DomainAnimals", bundle: .module)
    public static let domainHealth = Color("DomainHealth", bundle: .module)
    public static let domainWater = Color("DomainWater", bundle: .module)
    public static let surfacePrimary = Color("SurfacePrimary", bundle: .module)
    public static let surfaceSecondary = Color("SurfaceSecondary", bundle: .module)
}
