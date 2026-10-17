import MorseCore
import SwiftUI

/// The reference sheet for one cell: the glyph, its code, both skill lines, a play ring and Practice.
/// For the next cell: the glyph and "Unlocks when your set is solid".
struct CharacterSheet: View {
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
                    isPresented = false
                    onPractice(character)
                }
            } else {
                CrossfadeText("Unlocks when your set is solid")
                    .font(LampFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(palette.fgDim)
            }
        }
        .onDisappear { model.tone.stop() }
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
