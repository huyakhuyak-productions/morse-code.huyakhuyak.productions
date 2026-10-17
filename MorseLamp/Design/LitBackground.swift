import SwiftUI

/// The screen tint while a tone sounds. Lit on/off is instant: no implicit animation.
struct LitBackground: View {
    @Environment(LampState.self) private var lamp
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityDimFlashingLights) private var dimFlashing

    var body: some View {
        Rectangle()
            .fill(lamp.isLit && !dimFlashing ? palette.lit : palette.bg)
            .ignoresSafeArea()
            .transaction { $0.animation = nil }
    }
}
