import MorseCore
import SwiftUI

/// Every custom control bound to local state, reached with `--screen controls`. For UI tests and eyeballing.
struct ControlsGallery: View {
    @State private var strictTiming = false
    @State private var answerMode = AnswerMode.automatic
    @State private var wpm = 15.0
    @State private var confirmingReset = false
    @State private var resetConfirmed = false
    @State private var session = KeyingSession(estimator: DitEstimator())
    @State private var readout = ""

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                LampSwitch("Strict timing", explanation: "Dashes must be about three dots long.", isOn: $strictTiming)
                LampSegmented("Answer with", selection: $answerMode) { mode in
                    switch mode {
                    case .automatic: "Automatic"
                    case .choices: "Choices"
                    case .keyboard: "Keyboard"
                    }
                }
                LampSlider("Character speed", value: $wpm, in: 10...30, step: 1) { "\(Int($0)) wpm" }
                PrimaryButton("Reset progress", role: .destructive) { confirmingReset = true }
                CrossfadeText(resetConfirmed ? "Confirmed" : "Nothing reset")
                    .font(LampFont.body(15))
                    .foregroundStyle(palette.fgDim)
                // The live readout is one of the spec's instant exceptions: no crossfade.
                Text(readout)
                    .font(LampFont.glyph(28))
                    .foregroundStyle(palette.fg)
                    .frame(maxWidth: .infinity, minHeight: 40)
                PaddleView(
                    onDown: { session.keyDown(at: $0) },
                    onUp: { t in
                        _ = session.keyUp(at: t)
                        readout = Code(elements: session.elements).display
                    },
                    enabled: true
                )
            }
            .padding(16)
        }
        .confirmSheet(
            isPresented: $confirmingReset,
            title: "Reset all progress?",
            message: "This locks everything except K and M.",
            destructiveTitle: "Reset"
        ) {
            resetConfirmed = true
        }
    }
}
