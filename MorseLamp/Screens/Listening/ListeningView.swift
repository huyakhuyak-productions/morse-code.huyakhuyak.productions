import MorseCore
import SwiftUI

/// The lamp plays a character; the learner names it from a few choices or the full grid.
struct ListeningView: View {
    @State private var model: ListeningModel?

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        Group {
            if let model {
                drill(model)
            } else {
                Color.clear
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let model = self.model ?? ListeningModel(app: app, tone: app.tone, haptics: app.haptics)
            self.model = model
            await model.appear()
        }
        .onDisappear { model?.disappear() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model?.disappear()
            case .active: Task { await model?.appear() }
            default: break
            }
        }
    }

    private func drill(_ model: ListeningModel) -> some View {
        let progress = app.state.progress
        let answered = model.phase == .right || isWrong(model.phase)
        return VStack(spacing: 0) {
            DrillTopBar(unlocked: progress.unlockedCount, hasNext: progress.next != nil)
            Spacer(minLength: 0)
            ZStack {
                if answered {
                    Text(String(model.answer))
                        .font(LampFont.glyph(128))
                        .tracking(-0.05 * 128)
                        .foregroundStyle(palette.accent)
                        .transition(.opacity)
                } else {
                    LampDisc(isLit: app.lamp.isLit, showsPlayMark: model.phase == .awaiting) {
                        Task { await model.replay() }
                    }
                }
            }
            .frame(height: 160)
            .animation(.lamp(0.2), value: answered)
            Group {
                if let code = model.revealedCode {
                    CodeView(code, scale: .hint, color: palette.fg)
                        .accessibilityIdentifier("code")
                } else {
                    Color.clear
                }
            }
            .frame(height: 8)
            .padding(.top, 24)
            CrossfadeText(model.status)
                .font(LampFont.body(17))
                .foregroundStyle(palette.fg)
                .frame(minHeight: 24)
                .padding(.top, 20)
                .accessibilityIdentifier("status")
            Spacer(minLength: 0)
            answers(model)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func answers(_ model: ListeningModel) -> some View {
        switch model.answerMode {
        case .keyboard:
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Morse.gridOrder, id: \.self) { character in
                    AnswerCell(character: character, state: cellState(character, model), enabled: model.isEnabled(character), height: 48) {
                        Task { await model.pick(character) }
                    }
                }
            }
        case .choices, .automatic:
            HStack(spacing: 12) {
                ForEach(model.options, id: \.self) { character in
                    AnswerCell(character: character, state: cellState(character, model), enabled: true, height: 88) {
                        Task { await model.pick(character) }
                    }
                }
            }
        }
    }

    private func cellState(_ character: Character, _ model: ListeningModel) -> AnswerCell.State {
        switch model.phase {
        case .right:
            return character == model.answer ? .picked : .plain
        case .wrong(let picked):
            if character == picked { return .wrongPick }
            return character == model.answer ? .answer : .plain
        case .playing, .awaiting, .hold:
            if case .guided = model.mode, character == model.answer { return .answer }
            return .plain
        }
    }

    private func isWrong(_ phase: ListeningModel.Phase) -> Bool {
        if case .wrong = phase { return true }
        return false
    }
}

/// One answer: a muted cell that turns accent when it was the right pick, red when it was the
/// wrong one, and wears an accent ring when it is the answer being shown.
private struct AnswerCell: View {
    enum State { case plain, picked, wrongPick, answer }

    let character: Character
    let state: State
    let enabled: Bool
    let height: CGFloat
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(String(character))
                .font(LampFont.glyph(height > 60 ? 40 : 22))
                .tracking(-0.05 * (height > 60 ? 40 : 22))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
                .overlay {
                    if state == .answer {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.accent, lineWidth: 2)
                    }
                }
                .opacity(enabled ? 1 : 0.22)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .animation(.lamp(0.2), value: state)
        .accessibilityLabel("Answer \(character)")
    }

    private var fill: Color {
        switch state {
        case .plain, .answer: palette.muted
        case .picked: palette.accent
        case .wrongPick: palette.bad
        }
    }

    private var textColor: Color {
        switch state {
        case .picked, .wrongPick: .white
        case .plain, .answer: palette.fg
        }
    }
}
