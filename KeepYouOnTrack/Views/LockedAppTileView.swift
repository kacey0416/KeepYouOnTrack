import SwiftUI
import FamilyControls
import ManagedSettings

struct LockedAppTileView: View {
    let token: ApplicationToken
    let isEditing: Bool
    let onDelete: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Label(token)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 46))
                    .frame(width: 58, height: 58)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppDesignTokens.backgroundBlackSoft.opacity(0.98))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
            )
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .onLongPressGesture(minimumDuration: 0.35, perform: onLongPress)

            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.7), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("앱 잠금 해제")
            }
        }
    }
}
