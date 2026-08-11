import SwiftUI

struct SessionInputToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(AppDesignTokens.backgroundBlackSoft.opacity(0.96), in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}
