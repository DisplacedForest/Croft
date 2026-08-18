import Foundation
import XCTest

final class ColorLiteralSourceAuditTests: XCTestCase {
    func testSharedViewSourcesUseNoColorLiteralsOutsideTheTokenLayer() throws {
        let shared = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Shared")
        let forbidden = [
            "Color(red:",
            "Color(hue:",
            "Color(white:",
            "Color(.sRGB",
            "Color.white",
            "Color.black",
            "NSColor(",
            "UIColor(",
            "preferredColorScheme",
        ]
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(at: shared, includingPropertiesForKeys: nil))
        var audited = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            audited += 1
            for pattern in forbidden {
                XCTAssertFalse(
                    source.contains(pattern),
                    "\(url.lastPathComponent) contains \(pattern)")
            }
        }
        XCTAssertGreaterThan(audited, 0)
    }
}
