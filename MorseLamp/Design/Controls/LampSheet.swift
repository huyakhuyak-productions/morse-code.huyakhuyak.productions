import SwiftUI

/// A bottom sheet in the Lamp style: 24 pt radius, slides up over a scrim in 320 ms, modal to VoiceOver.
struct LampSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let titleFont: Font
    let titleTracking: CGFloat
    let content: Content

    @AccessibilityFocusState private var titleFocused: Bool
    @Environment(\.palette) private var palette

    init(isPresented: Binding<Bool>, title: String, titleFont: Font = LampFont.title(22), titleTracking: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.title = title
        self.titleFont = titleFont
        self.titleTracking = titleTracking
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CrossfadeText(title)
                .font(titleFont)
                .tracking(titleTracking)
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
        .task {
            // VoiceOver ignores a focus request made mid-transition; wait for the slide to land.
            try? await Task.sleep(for: .milliseconds(350))
            titleFocused = true
        }
    }
}

/// Presents any sheet view over the content, behind a scrim that dismisses it.
private struct LampPresenter<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    /// Runs after dismissal; callers move VoiceOver focus back to the control that opened the sheet.
    var onDismiss: (() -> Void)? = nil
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
        .onChange(of: isPresented) { _, shown in
            if !shown { onDismiss?() }
        }
    }
}

extension View {
    /// Presents any Lamp-style sheet view over this one, behind the shared scrim.
    func lampPresentation<S: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder sheet: @escaping () -> S) -> some View {
        modifier(LampPresenter(isPresented: isPresented, onDismiss: onDismiss, sheet: sheet))
    }

    func lampSheet<C: View>(isPresented: Binding<Bool>, title: String, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> C) -> some View {
        modifier(LampPresenter(isPresented: isPresented, onDismiss: onDismiss) {
            LampSheet(isPresented: isPresented, title: title, content: content)
        })
    }

    func confirmSheet(isPresented: Binding<Bool>, title: String, message: String, destructiveTitle: String, onDismiss: (() -> Void)? = nil, onConfirm: @escaping () -> Void) -> some View {
        modifier(LampPresenter(isPresented: isPresented, onDismiss: onDismiss) {
            ConfirmSheet(isPresented: isPresented, title: title, message: message, destructiveTitle: destructiveTitle, onConfirm: onConfirm)
        })
    }
}
