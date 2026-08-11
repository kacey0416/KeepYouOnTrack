import SwiftUI
import FamilyControls
import ManagedSettings

struct LockedAppsGridView: View {
    let tokens: [ApplicationToken]
    let isEditing: Bool
    let onDelete: (ApplicationToken) -> Void
    let onEnterEditing: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 78, maximum: 90), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(tokens, id: \.self) { token in
                    LockedAppTileView(
                        token: token,
                        isEditing: isEditing,
                        onDelete: { onDelete(token) },
                        onLongPress: onEnterEditing
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .frame(minHeight: 160, maxHeight: 360)
    }
}
