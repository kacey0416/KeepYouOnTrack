import SwiftUI

struct AddLockedAppButton: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: action) {
                ZStack {
                    Image("eggIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150)
                }
            }
            .buttonStyle(.plain)


        }
        .frame(maxWidth: .infinity)
    }
}
