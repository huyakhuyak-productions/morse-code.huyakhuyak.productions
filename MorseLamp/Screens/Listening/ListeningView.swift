import MorseCore
import SwiftUI

/// The lamp plays a character; the learner names it from a few choices or the full grid.
struct ListeningView: View {
    @Binding var path: [Route]

    @State private var model: ListeningModel?
    @State private var reveal: RevealModel?
    @State private var showingNudge = false
    /// "Key now" was tapped: the sheet's dismissal must not resume this drill.
    @State private var tookNudge = false
    @AccessibilityFocusState private var promptFocused: Bool

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        ZStack {
            if let model, let reveal {
                RevealView(model: reveal) {
                    self.reveal = nil
                    Task { await model.resumeAfterReveal() }
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
        .lampPresentation(isPresented: $showingNudge, onDismiss: {
            guard !tookNudge, let model else { return }
            promptFocused = true
            Task { await model.resumeAfterNudge() }
        }) {
            if let next = app.state.progress.next {
                NudgeSheet(isPresented: $showingNudge, from: .listening, next: next, character: app.nudgeCharacter) {
                    tookNudge = true
                    model?.handOver()
                    model?.dismissNudge()
                    guard !path.isEmpty else { return }
                    path[path.count - 1] = .keying(practice: nil)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let model = self.model ?? ListeningModel(app: app, tone: app.tone, haptics: app.haptics)
            self.model = model
            await model.appear()
        }
        .onChange(of: model?.revealReady) { _, ready in
            guard let model, ready != nil, reveal == nil else { return }
            reveal = RevealModel(app: app, from: .listening, tone: model.tone, haptics: app.haptics)
        }
        .onChange(of: model?.nudgeReady) { _, ready in
            if ready == true { showingNudge = true }
        }
        .onDisappear { model?.disappear() }
        .onBackgroundReturn(leave: { model?.disappear() }) {
            if reveal != nil { await app.tone.start() } else { await model?.appear() }
        }
    }

    private func drill(_ model: ListeningModel) -> some View {
        let progress = app.state.progress
        let answered = model.phase == .right || isWrong(model.phase)
        return VStack(spacing: 0) {
            DrillTopBar(unlocked: progress.unlockedCount, hasNext: progress.next != nil, nextFraction: app.outlook.fraction)
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
                    .accessibilityFocused($promptFocused)
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
                    AnswerCell(character: character, state: cellState(character, model), enabled: model.isEnabled(character), height: 48, label: "Answer \(character)") {
                        Task { await model.pick(character) }
                    }
                }
            }
        case .choices, .automatic:
            HStack(spacing: 12) {
                ForEach(model.options, id: \.self) { character in
                    AnswerCell(character: character, state: cellState(character, model), enabled: true, height: 88, label: "Answer \(character)") {
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
