import SwiftUI

public enum DesignResources {
    public static let bundle = Bundle.module
}

public enum ColorToken: String, CaseIterable, Sendable {
    case domainGarden = "DomainGarden"
    case domainAnimals = "DomainAnimals"
    case domainHealth = "DomainHealth"
    case domainWater = "DomainWater"
    case surfacePrimary = "SurfacePrimary"
    case surfaceSecondary = "SurfaceSecondary"

    public var color: Color {
        Color(rawValue, bundle: .module)
    }
}

extension Color {
    public static let domainGarden = ColorToken.domainGarden.color
    public static let domainAnimals = ColorToken.domainAnimals.color
    public static let domainHealth = ColorToken.domainHealth.color
    public static let domainWater = ColorToken.domainWater.color
    public static let surfacePrimary = ColorToken.surfacePrimary.color
    public static let surfaceSecondary = ColorToken.surfaceSecondary.color
}
