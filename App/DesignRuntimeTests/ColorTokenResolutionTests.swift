import AppKit
import Design
import XCTest

final class ColorTokenResolutionTests: XCTestCase {
    func testEveryTokenResolvesFromTheCompiledCatalog() {
        for token in ColorToken.allCases {
            XCTAssertNotNil(
                NSColor(named: token.rawValue, bundle: DesignResources.bundle),
                token.rawValue
            )
        }
    }

    func testEveryTokenResolvesInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            for token in ColorToken.allCases {
                var resolved: NSColor?
                appearance.performAsCurrentDrawingAppearance {
                    resolved = NSColor(named: token.rawValue, bundle: DesignResources.bundle)?
                        .usingColorSpace(.sRGB)
                }
                XCTAssertNotNil(resolved, "\(token.rawValue) in \(name.rawValue)")
            }
        }
    }

    func testEveryTokenResolvesDistinctValuesPerAppearance() throws {
        for token in ColorToken.allCases {
            var components: [NSAppearance.Name: [CGFloat]] = [:]
            for name in [NSAppearance.Name.aqua, .darkAqua] {
                let appearance = try XCTUnwrap(NSAppearance(named: name))
                appearance.performAsCurrentDrawingAppearance {
                    guard
                        let resolved = NSColor(
                            named: token.rawValue, bundle: DesignResources.bundle)?
                            .usingColorSpace(.sRGB)
                    else {
                        return
                    }
                    components[name] = [
                        resolved.redComponent,
                        resolved.greenComponent,
                        resolved.blueComponent,
                    ]
                }
            }
            let light = try XCTUnwrap(components[.aqua], token.rawValue)
            let dark = try XCTUnwrap(components[.darkAqua], token.rawValue)
            XCTAssertNotEqual(
                light, dark,
                "\(token.rawValue) resolves identically in aqua and darkAqua")
        }
    }
}
