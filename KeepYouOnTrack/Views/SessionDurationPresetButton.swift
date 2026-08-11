import SwiftUI

struct SessionDurationPresetButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SessionDurationButtonSurface(isSelected: isSelected) {
                VStack(spacing: 6) {
                    Text("\(minutes)")
                        .font(.title3)
                        .bold()

                    Text("분")
                        .font(.callout)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes)분")
        .accessibilityHint("이 시간 동안 선택한 앱의 잠금을 해제합니다.")
    }
}
