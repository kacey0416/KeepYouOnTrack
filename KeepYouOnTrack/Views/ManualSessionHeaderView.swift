import SwiftUI

struct ManualSessionHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppDesignTokens.accent.opacity(0.18))
                    .frame(width: 88, height: 88)
                    .blur(radius: 10)

                Image(systemName: "eye.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppDesignTokens.accent)
                    .accessibilityHidden(true)
            }

        }
    }
}
