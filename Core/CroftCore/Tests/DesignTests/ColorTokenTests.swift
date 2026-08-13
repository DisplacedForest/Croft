import Foundation
import Testing

@testable import Design

private let domainTokens: [ColorToken] = [
    .domainGarden,
    .domainAnimals,
    .domainHealth,
    .domainWater,
]

private let surfaceTokens: [ColorToken] = [
    .surfacePrimary,
    .surfaceSecondary,
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

private let packageURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private let catalogURL =
    packageURL
    .appendingPathComponent("Sources")
    .appendingPathComponent("Design")
    .appendingPathComponent("Colors.xcassets")

private let accentColorURL =
    packageURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("App")
    .appendingPathComponent("Shared")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AccentColor.colorset")
    .appendingPathComponent("Contents.json")

private func resolve(_ url: URL, dark: Bool) throws -> RGB {
    let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    let entry = try #require(catalog.colors.first { $0.isDark == dark })
    let components = entry.color.components
    let red = try #require(Double(components.red))
    let green = try #require(Double(components.green))
    let blue = try #require(Double(components.blue))
    return RGB(red: red, green: green, blue: blue)
}

private func resolve(_ token: ColorToken, dark: Bool) throws -> RGB {
    let url =
        catalogURL
        .appendingPathComponent("\(token.rawValue).colorset")
        .appendingPathComponent("Contents.json")
    return try resolve(url, dark: dark)
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

@Test(arguments: ColorToken.allCases)
func tokenHasColorsetInCatalog(token: ColorToken) {
    let url = catalogURL.appendingPathComponent("\(token.rawValue).colorset")
    #expect(FileManager.default.fileExists(atPath: url.path))
}

@Test(arguments: ColorToken.allCases)
func tokenDefinesBothAppearances(token: ColorToken) throws {
    let light = try resolve(token, dark: false)
    let dark = try resolve(token, dark: true)
    let differs =
        abs(light.red - dark.red) > 0.001
        || abs(light.green - dark.green) > 0.001
        || abs(light.blue - dark.blue) > 0.001
    #expect(differs)
}

@Test(arguments: domainTokens)
func tintOverOwnTintedCircleMeetsContrast(token: ColorToken) throws {
    for dark in [false, true] {
        let tint = try resolve(token, dark: dark)
        let surface = try resolve(.surfacePrimary, dark: dark)
        let circle = composite(tint, over: surface, opacity: 0.12)
        #expect(contrast(tint, circle) >= 4.5)
    }
}

@Test(arguments: surfaceTokens)
func surfaceContrastsWithPrimaryText(token: ColorToken) throws {
    let black = RGB(red: 0, green: 0, blue: 0)
    let white = RGB(red: 1, green: 1, blue: 1)
    let light = try resolve(token, dark: false)
    #expect(contrast(light, black) >= 4.5)
    let dark = try resolve(token, dark: true)
    #expect(contrast(dark, white) >= 4.5)
}

@Test func accentColorMatchesGardenToken() throws {
    for dark in [false, true] {
        let accent = try resolve(accentColorURL, dark: dark)
        let garden = try resolve(.domainGarden, dark: dark)
        #expect(abs(accent.red - garden.red) < 0.001)
        #expect(abs(accent.green - garden.green) < 0.001)
        #expect(abs(accent.blue - garden.blue) < 0.001)
    }
}
