import SwiftUI

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Croft")
                .font(.largeTitle.weight(.semibold))
        }
        .frame(minWidth: 320, minHeight: 240)
    }
}
