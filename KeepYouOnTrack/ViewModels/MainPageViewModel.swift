import Foundation
import Combine
import SwiftUI

@MainActor
final class MainPageViewModel: ObservableObject {
    @Published var isManualInputPresented: Bool = false

    private let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    init(sessionManager: SessionManager = .shared) {
        self.sessionManager = sessionManager

        sessionManager.$showManualInputScreen
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isPresented in
                self?.isManualInputPresented = isPresented
            }
            .store(in: &cancellables)
    }

    func refreshManualInputRequestIfNeeded() {
        sessionManager.consumeManualInputRequestIfNeeded()
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase == .background, isManualInputPresented else { return }
        sessionManager.dismissManualInput()
    }
}
