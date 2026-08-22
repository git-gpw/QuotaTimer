import SwiftUI
import Sparkle

struct CheckForUpdatesView: View {
    @StateObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        _checkForUpdatesViewModel = StateObject(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…") {
            checkForUpdatesViewModel.updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
        .buttonStyle(.borderless)
        .font(.caption)
    }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }
}
