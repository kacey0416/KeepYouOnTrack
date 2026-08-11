import SwiftUI

struct ManualSessionInputView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @FocusState private var isPurposeFocused: Bool
    @FocusState private var isCustomDurationFocused: Bool
    @State private var purpose = ""
    @State private var selectedMinutes = 5
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var toastMessage: String?
    @State private var toastRevision = 0

    private let presetDurations = [1, 5, 10, 15]

    private var trimmedPurpose: String {
        purpose.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isStartDisabled: Bool {
        trimmedPurpose.isEmpty || isSubmitting
    }

    var body: some View {
        ZStack(alignment: .top) {
            SessionInputBackgroundView()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)

            VStack(spacing: 28) {
                HStack {
                    Spacer()

                    Button("입력 화면 닫기", systemImage: "xmark", action: dismissManualInput)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minWidth: 44, minHeight: 44)
                        .background(.white.opacity(0.08), in: Circle())
                }

                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    ManualSessionHeaderView()

                    PurposePromptFieldView(
                        text: $purpose,
                        isFocused: $isPurposeFocused,
                        showsError: errorMessage != nil,
                        onSubmit: dismissKeyboard
                    )

                    VStack(spacing: 14) {
                        Text("집중 시간")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.72))

                        SessionDurationPicker(
                            selectedMinutes: $selectedMinutes,
                            presetDurations: presetDurations,
                            isCustomDurationFocused: $isCustomDurationFocused,
                            onInteraction: handleDurationInteraction,
                            onValidationError: showDurationValidationToast
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 560)

                Spacer(minLength: 0)

                Button(action: submitSession) {
                    Text("\(selectedMinutes)분 동안 잠금 풀기")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(isStartDisabled ? .white.opacity(0.55) : .black)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    isStartDisabled
                                    ? .white.opacity(0.12)
                                    : AppDesignTokens.accent
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isStartDisabled)
                .frame(maxWidth: 560)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            if let toastMessage {
                SessionInputToastView(message: toastMessage)
                    .padding(.horizontal, 24)
                    .padding(.top, 76)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: purpose) { _, _ in
            errorMessage = nil
        }
        .task {
            isPurposeFocused = true
        }
        .task(id: toastRevision) {
            guard toastMessage != nil else { return }

            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            withAnimation(.easeOut(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }

    private func dismissManualInput() {
        sessionManager.dismissManualInput()
    }

    private func dismissKeyboard() {
        isPurposeFocused = false
        isCustomDurationFocused = false
    }

    private func handleDurationInteraction() {
        isPurposeFocused = false
        errorMessage = nil
    }

    private func showDurationValidationToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = "1부터 60까지만 입력이 가능합니다"
        }
        toastRevision += 1
    }

    private func submitSession() {
        guard !isSubmitting else { return }

        dismissKeyboard()

        let normalizedPurpose = trimmedPurpose
        guard !normalizedPurpose.isEmpty else {
            errorMessage = "목적을 한 줄로 적어주세요."
            isPurposeFocused = true
            return
        }

        isSubmitting = true
        sessionManager.startSessionFromManualInput(
            purpose: normalizedPurpose,
            minutes: selectedMinutes
        )
    }
}

#Preview {
    ManualSessionInputView()
}
