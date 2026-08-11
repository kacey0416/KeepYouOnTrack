import SwiftUI
import FamilyControls
import ManagedSettings

struct AppSelectionView: View {
    @StateObject private var appGroup = LockedAppGroup()
    @State private var isPresentingPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var isEditingLockedApps = false

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var sortedApplicationTokens: [ApplicationToken] {
        appGroup.selectedApps.applicationTokens.sorted {
            String(describing: $0) < String(describing: $1)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 28) {
                    AddLockedAppButton(action: presentPicker)

                    LockedAppsSectionView(
                        tokens: sortedApplicationTokens,
                        isEditing: isEditingLockedApps,
                        onFinishEditing: exitDeleteMode,
                        onDelete: removeApplicationToken,
                        onEnterEditing: enterDeleteMode
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: exitDeleteMode)
            .modifier(
                PreviewSafeFamilyActivityPicker(
                    isPreview: isPreview,
                    isPresented: $isPresentingPicker,
                    selection: $draftSelection
                )
            )
            .onChange(of: draftSelection, initial: false) { _, updatedSelection in
                handleDraftSelectionChange(updatedSelection)
            }
            .onChange(of: isPresentingPicker, initial: false) { _, isPresented in
                handlePickerPresentationChange(isPresented)
            }
            .onAppear(perform: synchronizeSelectionState)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                AppDesignTokens.backgroundBlackDeep,
                AppDesignTokens.backgroundBlack,
                AppDesignTokens.backgroundBlackSoft
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppDesignTokens.accent.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 90, y: -40)
                .allowsHitTesting(false)
        }
    }

    private func presentPicker() {
        exitDeleteMode()
        draftSelection = appOnlySelection(from: appGroup.selectedApps)
        isPresentingPicker = true
    }

    private func synchronizeSelectionState() {
        let sanitizedSelection = appOnlySelection(from: appGroup.selectedApps)
        appGroup.selectedApps = sanitizedSelection
        draftSelection = sanitizedSelection
    }

    private func handleDraftSelectionChange(_ updatedSelection: FamilyActivitySelection) {
        let sanitizedSelection = appOnlySelection(from: updatedSelection)
        if updatedSelection.categoryTokens.isEmpty {
            return
        }
        draftSelection = sanitizedSelection
    }

    private func handlePickerPresentationChange(_ isPresented: Bool) {
        guard !isPresented else { return }
        commitSelection()
    }

    private func commitSelection() {
        let sanitizedSelection = appOnlySelection(from: draftSelection)
        let currentSelection = appOnlySelection(from: appGroup.selectedApps)
        guard currentSelection.applicationTokens != sanitizedSelection.applicationTokens else {
            return
        }

        appGroup.selectedApps = sanitizedSelection
        applyLockedSelection(sanitizedSelection)
    }

    private func applyLockedSelection(_ selection: FamilyActivitySelection) {
        guard !isPreview else { return }

        if selection.applicationTokens.isEmpty {
            FamilyControlsService.shared.stopMonitoring()
        } else {
            FamilyControlsService.shared.applyLock(selection: selection)
        }
    }

    private func appOnlySelection(from selection: FamilyActivitySelection) -> FamilyActivitySelection {
        var sanitizedSelection = FamilyActivitySelection()
        sanitizedSelection.applicationTokens = selection.applicationTokens
        return sanitizedSelection
    }

    private func enterDeleteMode() {
        guard !sortedApplicationTokens.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            isEditingLockedApps = true
        }
    }

    private func exitDeleteMode() {
        guard isEditingLockedApps else { return }
        withAnimation(.snappy(duration: 0.2)) {
            isEditingLockedApps = false
        }
    }

    private func removeApplicationToken(_ token: ApplicationToken) {
        var updatedSelection = appOnlySelection(from: appGroup.selectedApps)
        updatedSelection.applicationTokens.remove(token)
        draftSelection = updatedSelection
        appGroup.selectedApps = updatedSelection
        applyLockedSelection(updatedSelection)

        if updatedSelection.applicationTokens.isEmpty {
            exitDeleteMode()
        }
    }
}

#Preview {
    AppSelectionView()
}
