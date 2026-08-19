import Design
import SwiftUI

struct ScreenSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.surfacePrimary)
    }
}

extension View {
    func croftScreenSurface() -> some View {
        modifier(ScreenSurface())
    }
}
