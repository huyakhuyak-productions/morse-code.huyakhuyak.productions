import MorseCore
import SwiftUI

/// Target glyph, readout of what you keyed, hint, status, and the paddle.
struct KeyingView: View {
    let practice: Character?

    @State private var model: KeyingModel?
    @State private var reveal: RevealModel?

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let model, let reveal {
                RevealView(model: reveal) {
                    self.reveal = nil
                    model.resumeAfterReveal()
                }
                .transition(.opacity)
            } else if let model {
                drill(model)
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .animation(.lamp(0.32), value: reveal == nil)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let model = self.model ?? KeyingModel(app: app, tone: app.tone, haptics: app.haptics, practice: practice)
            self.model = model
            await model.appear()
        }
        .onChange(of: model?.revealReady) { _, ready in
            guard let model, ready != nil, reveal == nil else { return }
            reveal = RevealModel(app: app, from: .keying, tone: model.tone, haptics: app.haptics)
        }
        .onDisappear { model?.disappear() }
        .onBackgroundReturn(leave: { model?.disappear() }) {
            // Under the reveal only the engine needs restarting; the drill resumes after "Keep going".
            if reveal != nil { await app.tone.start() } else { await model?.appear() }
        }
        .onChange(of: model?.didFinishPractice ?? false) { _, finished in
            if finished { dismiss() }
        }
    }

    private func drill(_ model: KeyingModel) -> some View {
        let progress = app.state.progress
        let isMatched = model.phase == .matched
        return VStack(spacing: 0) {
            DrillTopBar(unlocked: progress.unlockedCount, hasNext: progress.next != nil, nextFraction: app.outlook.fraction)
            Spacer(minLength: 0)
            Text(String(model.target))
                .font(LampFont.glyph(212))
                .tracking(-0.05 * 212)
                .foregroundStyle(isMatched ? palette.accent : palette.fg)
                .scaleEffect(isMatched && !reduceMotion ? 1.03 : 1)
                .animation(.lamp(0.2), value: isMatched)
                .accessibilityIdentifier("target")
            readout(model)
                .frame(minHeight: 16)
                .padding(.top, 24)
                .modifier(Shake(trigger: model.shakeCount, enabled: !reduceMotion))
            Group {
                if let hint = model.hint {
                    CodeView(hint, scale: .hint, color: palette.fgDim)
                        .accessibilityIdentifier("hint")
                } else {
                    Color.clear
                }
            }
            .frame(height: 8)
            .padding(.top, 20)
            statusLine(model)
                .font(LampFont.body(17))
                .foregroundStyle(palette.fg)
                .frame(minHeight: 24)
                .padding(.top, 20)
                .accessibilityIdentifier("status")
            Spacer(minLength: 0)
            PaddleView(
                onDown: { model.keyDown(at: $0) },
                onUp: { model.keyUp(at: $0) },
                enabled: model.phase == .keying,
                dit: model.dit
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .defersSystemGestures(on: .bottom)
    }

    @ViewBuilder
    private func readout(_ model: KeyingModel) -> some View {
        let color = readoutColor(model.phase)
        if app.state.settings.strictTiming, !model.keyed.isEmpty {
            StrictReadout(elements: model.keyed, presses: model.presses, dit: model.dit, color: color, faultedOrdinal: faultedOrdinal(model.phase))
        } else {
            CodeView(Code(elements: model.keyed), scale: .full, color: color)
        }
    }

    /// The live pattern updates instantly; every other status change crossfades, including the
    /// hand-over between the two (first press, submit), which fades rather than cuts.
    private func statusLine(_ model: KeyingModel) -> some View {
        let live = model.phase == .keying && !model.keyed.isEmpty
        return ZStack {
            if live {
                Text(model.status).transition(.opacity)
            } else {
                CrossfadeText(model.status).transition(.opacity)
            }
        }
        .animation(.lamp(0.2), value: live)
    }

    private func readoutColor(_ phase: KeyingModel.Phase) -> Color {
        switch phase {
        case .matched: palette.accent
        case .missed(let fault): fault == nil ? palette.bad : palette.warn
        case .keying, .hold: palette.fg
        }
    }

    private func faultedOrdinal(_ phase: KeyingModel.Phase) -> Int? {
        if case .missed(let fault) = phase { return fault?.ordinal }
        return nil
    }
}

/// Strict timing: each element at its real length over a ghost of the ideal one or three units.
private struct StrictReadout: View {
    let elements: [Element]
    let presses: [Press]
    let dit: TimeInterval
    let color: Color
    let faultedOrdinal: Int?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(zip(elements, presses).enumerated()), id: \.offset) { index, pair in
                let (element, press) = pair
                let ideal: CGFloat = element == .dot ? 16 : 48
                let actual = max(6, CGFloat(press.duration / dit) * 16)
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.muted2).frame(width: ideal, height: 16)
                    Capsule().fill(faultedOrdinal == index + 1 ? palette.warn : color).frame(width: actual, height: 16)
                }
                .frame(width: max(ideal, actual), alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Code(elements: elements).spokenDescription)
    }
}

/// One horizontal shake: three 6 pt cycles over 320 ms. Nothing under Reduce Motion.
private struct Shake: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
            view.offset(x: enabled ? x : 0)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(6, duration: 0.053)
                LinearKeyframe(-6, duration: 0.053)
                LinearKeyframe(6, duration: 0.053)
                LinearKeyframe(-6, duration: 0.053)
                LinearKeyframe(6, duration: 0.053)
                LinearKeyframe(0, duration: 0.055)
            }
        }
    }
}
