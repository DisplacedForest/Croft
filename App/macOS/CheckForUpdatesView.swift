import Combine
import Sparkle
import SwiftUI

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    private let unavailableExplanation: String?

    init(updater: SPUUpdater, unavailableExplanation: String?) {
        self.updater = updater
        self.unavailableExplanation = unavailableExplanation
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        UpdateCommandContent(
            canCheckForUpdates: viewModel.canCheckForUpdates,
            unavailableExplanation: unavailableExplanation,
            checkForUpdates: { updater.checkForUpdates() }
        )
    }
}
