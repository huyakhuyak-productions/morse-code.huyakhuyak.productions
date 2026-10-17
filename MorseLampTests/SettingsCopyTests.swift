import Testing
@testable import MorseLamp

struct SettingsCopyTests {
    @Test func answerModeExplanations() {
        #expect(SettingsCopy.answerModeExplanation(.automatic) == "Choices until 10 letters are unlocked, then the keyboard.")
        #expect(SettingsCopy.answerModeExplanation(.choices) == "A few candidates every time.")
        #expect(SettingsCopy.answerModeExplanation(.keyboard) == "The full grid every time.")
    }
}
