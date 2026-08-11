import SwiftUI
import FamilyControls
import ManagedSettings

struct LockedAppsSectionView: View {
    let tokens: [ApplicationToken]
    let isEditing: Bool
    let onFinishEditing: () -> Void
    let onDelete: (ApplicationToken) -> Void
    let onEnterEditing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("잠금 앱")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)

                    Text(sectionDescription)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 12)

                if isEditing {
                    Button("완료", action: onFinishEditing)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppDesignTokens.accent)
                }
            }

            if tokens.isEmpty {
                LockedAppsEmptyStateView()
            } else {
                LockedAppsGridView(
                    tokens: tokens,
                    isEditing: isEditing,
                    onDelete: onDelete,
                    onEnterEditing: onEnterEditing
                )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        )
    }

    private var sectionDescription: String {
        if tokens.isEmpty {
            return "선택한 앱은 여기에서 한눈에 확인됩니다."
        }

        if isEditing {
            return "아이콘의 x 버튼을 눌러 잠금 목록에서 제거하세요."
        }

        return "앱 아이콘을 길게 눌러 삭제 모드로 들어갈 수 있습니다."
    }
}
