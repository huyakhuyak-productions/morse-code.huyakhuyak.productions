import MorseCore
import SwiftUI

/// The reference sheet for one cell: the glyph, both skill lines, a play ring and Practice, with the
/// code when the setting shows codes. For the next cell: the glyph and what to drill before it
/// unlocks; its code and play ring only when the setting shows codes.
struct CharacterSheet: View {
    @State private var startedPractice = false
    @Binding var isPresented: Bool
    let character: Character
    let onPractice: (Character) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        LampSheet(isPresented: $isPresented, title: String(character), titleFont: LampFont.glyph(128), titleTracking: -0.05 * 128) {
            let outlook = model.outlook
            let state = HomeCells.state(of: character, in: model.state.progress, nextFraction: outlook.fraction)
            let showsCode = model.state.settings.showsCodes
            let code = Morse.code(for: character)
            if showsCode, let code {
                CodeView(code, scale: .hint, color: palette.fg)
                    .accessibilityIdentifier("code")
            }
            if case .unlocked = state {
                if let code { playRing(code) }
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
                if showsCode, let code { playRing(code) }
                CrossfadeText(nextLine(outlook))
                    .font(LampFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(palette.fgDim)
                distanceBar(outlook.fraction)
            }
        }
        // The sheet slides out after the practice drill has already started the shared engine, so
        // only a plain dismissal stops it; the drill owns it from here.
        .onDisappear { if !startedPractice { model.tone.stop() } }
    }

    /// "Key and listen to K and M until they stick, and R unlocks." before anything is logged,
    /// then the home sentence's advice: "Listen to M a few more times and R unlocks."
    private func nextLine(_ outlook: UnlockOutlook) -> String {
        let progress = model.state.progress
        guard progress.hasLoggedAttempts else {
            let unlocked = progress.unlocked
            return "Key and listen to \(unlocked[0]) and \(unlocked[1]) until they stick, and \(character) unlocks."
        }
        return HomeSummary.tail(outlook.advice, next: character)
    }

    /// The unlock distance as a 4 pt bar across the sheet body. Decorative: the cell's label
    /// already reads the percent.
    private func distanceBar(_ fraction: Double) -> some View {
        Capsule()
            .fill(palette.muted2)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: geometry.size.width * fraction)
                        .distanceAnimation(fraction)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(true)
    }

    private func playRing(_ code: Code) -> some View {
        HStack {
            Spacer()
            LampDisc(isLit: model.lamp.isLit, showsPlayMark: true, size: 96) { play(code) }
            Spacer()
        }
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
