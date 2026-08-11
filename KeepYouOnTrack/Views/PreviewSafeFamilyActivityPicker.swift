import SwiftUI
import FamilyControls

struct PreviewSafeFamilyActivityPicker: ViewModifier {
    let isPreview: Bool
    @Binding var isPresented: Bool
    @Binding var selection: FamilyActivitySelection

    func body(content: Content) -> some View {
        if isPreview {
            content
        } else {
            content.familyActivityPicker(
                isPresented: $isPresented,
                selection: $selection
            )
        }
    }
}
