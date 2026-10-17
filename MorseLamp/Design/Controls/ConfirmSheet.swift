import SwiftUI

/// The one dialog for destructive actions: title, one line, a red button, a muted Cancel.
struct ConfirmSheet: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let destructiveTitle: String
    let onConfirm: () -> Void

    @Environment(\.palette) private var palette

    init(isPresented: Binding<Bool>, title: String, message: String, destructiveTitle: String, onConfirm: @escaping () -> Void) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.destructiveTitle = destructiveTitle
        self.onConfirm = onConfirm
    }

    var body: some View {
        LampSheet(isPresented: $isPresented, title: title) {
            CrossfadeText(message)
                .font(LampFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(palette.fgDim)
            PrimaryButton(destructiveTitle, role: .destructive) {
                isPresented = false
                onConfirm()
            }
            PrimaryButton("Cancel", role: .muted) {
                isPresented = false
            }
        }
    }
}
