import Testing
import MorseCore
@testable import MorseLamp

struct SettingsCopyTests {
    @Test func answerModeExplanations() {
        #expect(SettingsCopy.answerModeExplanation(.automatic) == "Choices until 10 letters are unlocked, then the keyboard.")
        #expect(SettingsCopy.answerModeExplanation(.choices) == "A few candidates every time.")
        #expect(SettingsCopy.answerModeExplanation(.keyboard) == "The full grid every time.")
    }

    @Test func paceCopy() {
        #expect(UnlockPace.allCases.map(SettingsCopy.paceLabel) == ["Relaxed", "Standard", "Strict"])
        #expect(SettingsCopy.paceExplanation(.relaxed) == "New letters come quickly. Expect to revisit some.")
        #expect(SettingsCopy.paceExplanation(.standard) == "The Koch 90% rule, trimmed for one tap at a time.")
        #expect(SettingsCopy.paceExplanation(.strict) == "Each letter seasons for 20 rounds in both skills first.")
    }
}
