import MorseCore
import SwiftUI

/// The unlock reveal in place of a drill's content: the tick row stays, the lamp signals, three
/// guesses slide up, then the glyph lands with its code and the caption offers "Keep going".
struct RevealView: View {
    let model: RevealModel
    let onKeepGoing: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let glyphSize: CGFloat = 232

    var body: some View {
        let revealed = isRevealed(model.step)
        VStack(spacing: 0) {
            DrillTopBar(
                unlocked: revealed ? model.unlockedCount : model.unlockedCount - 1,
                hasNext: revealed ? model.unlockedCount < Morse.kochOrder.count : true,
                // Before the reveal the arriving letter's tick is full; after it the new next one is empty.
                nextFraction: revealed ? 0 : 1,
                newestAccent: revealed
            )
            Spacer(minLength: 0)
            ZStack {
                if revealed {
                    glyphAndCode
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.82).combined(with: .opacity))
                } else {
                    LampDisc(isLit: app.lamp.isLit, showsPlayMark: model.step == .guess, action: lampAction)
                        .transition(.opacity)
                }
            }
            .frame(height: Self.glyphSize + 64)
            .animation(.lamp(0.52), value: revealed)
            CrossfadeText(leadRuns, size: 17)
                .foregroundStyle(palette.fg)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .accessibilityIdentifier("lead")
            Spacer(minLength: 0)
            bottom
                .frame(height: 176)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .task { await model.run() }
    }

    private var glyphAndCode: some View {
        VStack(spacing: 32) {
            Text(String(model.character))
                .font(LampFont.glyph(Self.glyphSize))
                .tracking(-0.05 * Self.glyphSize)
                .foregroundStyle(palette.accent)
                .accessibilityIdentifier("target")
            CodeView(model.code, scale: .full, color: model.highlighted == nil ? palette.accent : palette.fg, highlighted: model.highlighted, stagger: 0.07)
                .accessibilityIdentifier("code")
        }
    }

    private var lampAction: (() -> Void)? {
        guard model.step == .guess else { return nil }
        return { Task { await model.replay() } }
    }

    private var leadRuns: [HomeSummary.Run] {
        model.step == .caption ? model.caption : [HomeSummary.Run(text: model.lead, isBold: false)]
    }

    @ViewBuilder
    private var bottom: some View {
        ZStack(alignment: .bottom) {
            if showsOptions {
                HStack(spacing: 12) {
                    ForEach(model.options, id: \.self) { character in
                        AnswerCell(character: character, state: cellState(character), enabled: model.step == .guess, height: 88, label: "Guess \(character)") {
                            Task { await model.pick(character) }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            if model.step == .caption {
                VStack(spacing: 24) {
                    LampDisc(isLit: app.lamp.isLit, showsPlayMark: true, size: 96) {
                        Task { await model.replay() }
                    }
                    PrimaryButton("Keep going") {
                        model.keepGoing()
                        onKeepGoing()
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.lamp(0.32), value: showsOptions)
        .animation(.lamp(0.32), value: model.step == .caption)
    }

    private var showsOptions: Bool {
        switch model.step {
        case .guess, .decided: true
        default: false
        }
    }

    private func cellState(_ character: Character) -> AnswerCell.State {
        guard case .decided = model.step else { return .plain }
        if character == model.character { return .picked }
        if character == model.picked { return .wrongPick }
        return .plain
    }

    private func isRevealed(_ step: RevealModel.Step) -> Bool {
        switch step {
        case .reveal, .hearing, .caption: true
        default: false
        }
    }
}
