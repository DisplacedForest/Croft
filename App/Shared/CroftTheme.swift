import SwiftUI

enum CroftTheme {
    static let unit: CGFloat = 4

    static func space(_ multiplier: CGFloat) -> CGFloat {
        unit * multiplier
    }

    static var display: Font {
        .system(.largeTitle, design: .serif).weight(.semibold)
    }

    static var heading: Font {
        .system(.title2, design: .serif).weight(.medium)
    }

    static var supporting: Font {
        .system(.callout)
    }
}
