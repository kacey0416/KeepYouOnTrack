import SwiftUI

struct CustomSessionDurationButton: View {
    let confirmedMinutes: Int?
    let isSelected: Bool
    let isEditing: Bool
    @Binding var draftText: String
    @FocusState.Binding var isFocused: Bool
    let onTap: () -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        Group {
            if let confirmedMinutes, !isEditing {
                confirmedButton(minutes: confirmedMinutes)
            } else {
                editableButton
            }
        }
        .animation(
            accessibilityReduceMotion ? nil : .snappy(duration: 0.24),
            value: isEditing
        )
    }

    private func confirmedButton(minutes: Int) -> some View {
        Button(action: onTap) {
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
        .accessibilityLabel("사용자 설정 \(minutes)분")
        .accessibilityHint(
            isSelected
            ? "사용자 설정 시간을 수정합니다."
            : "이 시간을 선택합니다."
        )
    }

    private var editableButton: some View {
        SessionDurationButtonSurface(isSelected: isEditing) {
            HStack(spacing: 0) {
                if isEditing {
                    TextField("분", text: $draftText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.title3.bold())
                        .foregroundStyle(.black)
                        .focused($isFocused)
                        .frame(minWidth: 18)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .accessibilityLabel("사용자 설정 시간")
                        .accessibilityHint("1분부터 60분 사이의 숫자를 입력합니다.")
                }

                Button(action: isEditing ? onConfirm : onTap) {
                    Label(
                        isEditing ? "사용자 설정 시간 확정" : "사용자 설정 시간 입력",
                        systemImage: isEditing ? "checkmark" : "plus"
                    )
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isEditing ? 2 : 0)
        }
        .task(id: isEditing) {
            guard isEditing else { return }
            await Task.yield()
            isFocused = true
        }
    }
}
