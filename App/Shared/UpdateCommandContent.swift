import SwiftUI

struct UpdateCommandContent: View {
    let canCheckForUpdates: Bool
    let unavailableExplanation: String?
    let checkForUpdates: () -> Void

    var body: some View {
        Button("Check for Updates…", action: checkForUpdates)
            .disabled(!canCheckForUpdates)
        if let unavailableExplanation {
            Text(unavailableExplanation)
        }
    }
}
