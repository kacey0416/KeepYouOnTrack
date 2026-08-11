import SwiftUI

struct LockedAppsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppDesignTokens.accent)

            Text("아직 잠금 앱이 없습니다")
                .font(.headline)
                .foregroundStyle(.white)

            Text("위의 추가 버튼을 눌러 사용을 막고 싶은 앱을 고르세요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppDesignTokens.backgroundBlackSoft.opacity(0.72))
        )
    }
}
