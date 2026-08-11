import SwiftUI

struct SessionDurationPicker: View {
    @Binding var selectedMinutes: Int
    let presetDurations: [Int]
    @FocusState.Binding var isCustomDurationFocused: Bool
    let onInteraction: () -> Void
    let onValidationError: () -> Void

    @State private var confirmedCustomMinutes: Int?
    @State private var isCustomSelected = false
    @State private var isEditingCustomDuration = false
    @State private var draftText = ""
    @State private var lastAcceptedDraftText = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(presetDurations, id: \.self) { minutes in
                    SessionDurationPresetButton(
                        minutes: minutes,
                        isSelected: isPresetSelected(minutes),
                        action: { selectPreset(minutes) }
                    )
                }
            }

            CustomSessionDurationButton(
                confirmedMinutes: confirmedCustomMinutes,
                isSelected: isCustomSelected,
                isEditing: isEditingCustomDuration,
                draftText: customDraftBinding,
                isFocused: $isCustomDurationFocused,
                onTap: handleCustomButtonTap,
                onConfirm: confirmCustomDuration
            )
            .frame(maxWidth: 220)
        }
        .onChange(of: isCustomDurationFocused) { _, isFocused in
            guard !isFocused else { return }
            cancelUnconfirmedCustomEdit()
        }
    }

    private var customDraftBinding: Binding<String> {
        Binding(
            get: { draftText },
            set: validateDraft
        )
    }

    private func isPresetSelected(_ minutes: Int) -> Bool {
        !isEditingCustomDuration && !isCustomSelected && selectedMinutes == minutes
    }

    private func selectPreset(_ minutes: Int) {
        onInteraction()
        isEditingCustomDuration = false
        isCustomDurationFocused = false
        isCustomSelected = false
        selectedMinutes = minutes
        restoreConfirmedDraft()
    }

    private func handleCustomButtonTap() {
        onInteraction()

        if let confirmedCustomMinutes, !isCustomSelected {
            selectedMinutes = confirmedCustomMinutes
            isCustomSelected = true
            return
        }

        beginCustomEdit()
    }

    private func beginCustomEdit() {
        restoreConfirmedDraft()
        isEditingCustomDuration = true
    }

    private func confirmCustomDuration() {
        guard let minutes = Int(draftText), (1...60).contains(minutes) else {
            onValidationError()
            return
        }

        confirmedCustomMinutes = minutes
        selectedMinutes = minutes
        isCustomSelected = true
        lastAcceptedDraftText = String(minutes)
        draftText = String(minutes)
        isEditingCustomDuration = false
        isCustomDurationFocused = false
    }

    private func validateDraft(_ newValue: String) {
        guard !newValue.isEmpty else {
            draftText = ""
            lastAcceptedDraftText = ""
            return
        }

        guard
            newValue.allSatisfy(\.isNumber),
            !newValue.hasPrefix("0"),
            let minutes = Int(newValue),
            (1...60).contains(minutes)
        else {
            draftText = lastAcceptedDraftText
            onValidationError()
            return
        }

        draftText = String(minutes)
        lastAcceptedDraftText = draftText
    }

    private func cancelUnconfirmedCustomEdit() {
        guard isEditingCustomDuration else { return }

        restoreConfirmedDraft()
        isEditingCustomDuration = false

        if let confirmedCustomMinutes {
            selectedMinutes = confirmedCustomMinutes
            isCustomSelected = true
        }
    }

    private func restoreConfirmedDraft() {
        let restoredText = confirmedCustomMinutes.map(String.init) ?? ""
        draftText = restoredText
        lastAcceptedDraftText = restoredText
    }
}
