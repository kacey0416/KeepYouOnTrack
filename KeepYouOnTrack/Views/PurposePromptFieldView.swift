import SwiftUI

struct PurposePromptFieldView: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let showsError: Bool
    let onSubmit: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var purposeFontSize = 30

    var body: some View {
        VStack(spacing: 14) {
            TextField(
                "",
                text: $text,
                prompt: Text("왜 이 앱을 열었더라?")
                    .foregroundStyle(.white.opacity(0.26))
            )
            .focused(isFocused)
            .font(.system(size: purposeFontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .lineLimit(1)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .onChange(of: text) { _, newValue in
                let normalizedValue = normalizedSingleLineText(from: newValue)
                if normalizedValue != newValue {
                    text = normalizedValue
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)

            Capsule()
                .fill(showsError ? Color.red : AppDesignTokens.accent)
                .frame(height: 2)
        }
    }

    private func normalizedSingleLineText(from value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
