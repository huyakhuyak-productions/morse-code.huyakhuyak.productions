import MorseCore
import SwiftUI

/// The reference sheet for one cell: the glyph, its code, both skill lines, a play ring and Practice.
/// For the next cell: the glyph and what to drill before it unlocks.
struct CharacterSheet: View {
    @State private var startedPractice = false
    @Binding var isPresented: Bool
    let character: Character
    let onPractice: (Character) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        LampSheet(isPresented: $isPresented, title: String(character), titleFont: LampFont.glyph(128), titleTracking: -0.05 * 128) {
            let state = HomeCells.state(of: character, in: model.state.progress)
            let showsCode = HomeCells.showsCode(state, codesOnLocked: model.state.settings.codesOnLocked)
            if showsCode, let code = Morse.code(for: character) {
                CodeView(code, scale: .hint, color: palette.fg)
                HStack {
                    Spacer()
                    LampDisc(isLit: model.lamp.isLit, showsPlayMark: true, size: 96) { play(code) }
                    Spacer()
                }
            }
            if case .unlocked = state {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Skill.allCases, id: \.self) { skill in
                        CrossfadeText(HomeCells.skillLine(skill, record: model.state.progress.record(character, skill)))
                    }
                }
                .font(LampFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(palette.fgDim)
                PrimaryButton("Practice \(character)") {
                    startedPractice = true
                    isPresented = false
                    onPractice(character)
                }
            } else {
                CrossfadeText(nextLine)
                    .font(LampFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(palette.fgDim)
            }
        }
        // The sheet slides out after the practice drill has already started the shared engine, so
        // only a plain dismissal stops it; the drill owns it from here.
        .onDisappear { if !startedPractice { model.tone.stop() } }
    }

    /// "Key and listen to K and M until they stick, and R unlocks." before anything is logged,
    /// then the home sentence's advice: "Listen to M a few more times and R unlocks."
    private var nextLine: String {
        let progress = model.state.progress
        guard progress.hasLoggedAttempts else {
            let unlocked = progress.unlocked
            return "Key and listen to \(unlocked[0]) and \(unlocked[1]) until they stick, and \(character) unlocks."
        }
        return HomeSummary.tail(UnlockOutlook(progress: progress, rule: model.rule).advice, next: character)
    }

    private func play(_ code: Code) {
        let schedule = PlaybackSchedule(code: code, wpm: model.state.settings.wpm)
        Task { @MainActor in
            await model.tone.start()
            model.tone.setPitch(model.state.settings.pitchHz)
            await model.tone.play(schedule)
        }
    }
}
