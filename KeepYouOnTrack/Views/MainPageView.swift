import SwiftUI

struct MainPageView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = MainPageViewModel()

    var body: some View {
        AppSelectionView()
            .onAppear(perform: viewModel.refreshManualInputRequestIfNeeded)
            .onChange(of: scenePhase) { _, phase in
                viewModel.handleScenePhaseChange(phase)
            }
            .fullScreenCover(isPresented: $viewModel.isManualInputPresented) {
                ManualSessionInputView()
            }
    }
}

#Preview {
    MainPageView()
}
