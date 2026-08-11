import SwiftUI

struct SessionDurationButtonSurface<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(isSelected ? Color.black : .white)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isSelected
                        ? AppDesignTokens.accent
                        : AppDesignTokens.backgroundBlackSoft.opacity(0.96)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? AppDesignTokens.accent : .white.opacity(0.12),
                        lineWidth: 1
                    )
            )
    }
}
