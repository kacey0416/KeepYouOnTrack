import SwiftUI

struct SessionInputBackgroundView: View {
    var body: some View {
        ZStack {
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

            Circle()
                .fill(AppDesignTokens.accent.opacity(0.28))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: 120, y: -250)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: -140, y: 220)
        }
        .accessibilityHidden(true)
    }
}
