import Foundation
import Testing

@testable import Design

private let domainTokens = [
    "DomainGarden",
    "DomainAnimals",
    "DomainHealth",
    "DomainWater",
]

private let surfaceTokens = [
    "SurfacePrimary",
    "SurfaceSecondary",
]

private struct RGB {
    let red: Double
    let green: Double
    let blue: Double
}

private struct Catalog: Decodable {
    let colors: [Entry]
}

private struct Entry: Decodable {
    let appearances: [Appearance]?
    let color: ColorDefinition

    var isDark: Bool {
        appearances?.contains { $0.appearance == "luminosity" && $0.value == "dark" } ?? false
    }
}

private struct Appearance: Decodable {
    let appearance: String
    let value: String
}

private struct ColorDefinition: Decodable {
    let components: Components
}

private struct Components: Decodable {
    let red: String
    let green: String
    let blue: String
}

private let catalogURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Sources")
    .appendingPathComponent("Design")
    .appendingPathComponent("Colors.xcassets")

private func resolve(_ name: String, dark: Bool) throws -> RGB {
    let url =
        catalogURL
        .appendingPathComponent("\(name).colorset")
        .appendingPathComponent("Contents.json")
    let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    let entry = try #require(catalog.colors.first { $0.isDark == dark })
    let components = entry.color.components
    let red = try #require(Double(components.red))
    let green = try #require(Double(components.green))
    let blue = try #require(Double(components.blue))
    return RGB(red: red, green: green, blue: blue)
}

private func luminance(_ rgb: RGB) -> Double {
    func channel(_ value: Double) -> Double {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(rgb.red) + 0.7152 * channel(rgb.green) + 0.0722 * channel(rgb.blue)
}

private func contrast(_ first: RGB, _ second: RGB) -> Double {
    let lighter = max(luminance(first), luminance(second))
    let darker = min(luminance(first), luminance(second))
    return (lighter + 0.05) / (darker + 0.05)
}

private func composite(_ tint: RGB, over base: RGB, opacity: Double) -> RGB {
    RGB(
        red: tint.red * opacity + base.red * (1 - opacity),
        green: tint.green * opacity + base.green * (1 - opacity),
        blue: tint.blue * opacity + base.blue * (1 - opacity)
    )
}

@Test(arguments: domainTokens + surfaceTokens)
func tokenDefinesBothAppearances(name: String) throws {
    let light = try resolve(name, dark: false)
    let dark = try resolve(name, dark: true)
    let differs =
        abs(light.red - dark.red) > 0.001
        || abs(light.green - dark.green) > 0.001
        || abs(light.blue - dark.blue) > 0.001
    #expect(differs)
}

@Test(arguments: domainTokens)
func textOnTintedSurfaceMeetsContrast(name: String) throws {
    let black = RGB(red: 0, green: 0, blue: 0)
    let white = RGB(red: 1, green: 1, blue: 1)

    let lightBlend = composite(
        try resolve(name, dark: false),
        over: try resolve("SurfacePrimary", dark: false),
        opacity: 0.12
    )
    #expect(contrast(lightBlend, black) >= 4.5)

    let darkBlend = composite(
        try resolve(name, dark: true),
        over: try resolve("SurfacePrimary", dark: true),
        opacity: 0.12
    )
    #expect(contrast(darkBlend, white) >= 4.5)
}

@Test(arguments: surfaceTokens)
func surfaceContrastsWithPrimaryText(name: String) throws {
    let black = RGB(red: 0, green: 0, blue: 0)
    let white = RGB(red: 1, green: 1, blue: 1)
    let light = try resolve(name, dark: false)
    #expect(contrast(light, black) >= 4.5)
    let dark = try resolve(name, dark: true)
    #expect(contrast(dark, white) >= 4.5)
}
