import SwiftUI

/// A bottom sheet in the Lamp style: 24 pt radius, slides up over a scrim in 320 ms, modal to VoiceOver.
struct LampSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let content: Content

    @AccessibilityFocusState private var titleFocused: Bool
    @Environment(\.palette) private var palette

    init(isPresented: Binding<Bool>, title: String, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CrossfadeText(title)
                .font(LampFont.title(22))
                .foregroundStyle(palette.fg)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.bg)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.muted2, lineWidth: 1))
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { isPresented = false }
        .onAppear { titleFocused = true }
    }
}

/// Presents any sheet view over the content, behind a scrim that dismisses it.
private struct LampPresenter<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheet: () -> Sheet

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                .accessibilityHidden(isPresented)
            if isPresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { isPresented = false }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                sheet()
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.lamp(0.32), value: isPresented)
    }
}

extension View {
    func lampSheet<C: View>(isPresented: Binding<Bool>, title: String, @ViewBuilder content: @escaping () -> C) -> some View {
        modifier(LampPresenter(isPresented: isPresented) {
            LampSheet(isPresented: isPresented, title: title, content: content)
        })
    }

    func confirmSheet(isPresented: Binding<Bool>, title: String, message: String, destructiveTitle: String, onConfirm: @escaping () -> Void) -> some View {
        modifier(LampPresenter(isPresented: isPresented) {
            ConfirmSheet(isPresented: isPresented, title: title, message: message, destructiveTitle: destructiveTitle, onConfirm: onConfirm)
        })
    }
}
