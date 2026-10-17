import Testing
@testable import MorseCore

@Test func gridOrderIsAToZThenDigits() {
    #expect(Morse.gridOrder.count == 36)
    #expect(String(Morse.gridOrder) == "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
}

@Test func kochOrderCoversEveryCharacterOnce() {
    #expect(String(Morse.kochOrder) == "KMRSUAPTLOWINJEF0YVG5Q9ZH38B7C1D6X24")
    #expect(Set(Morse.kochOrder) == Set(Morse.gridOrder))
}

@Test func knownCodes() {
    #expect(Morse.code(for: "K")?.elements == [.dash, .dot, .dash])
    #expect(Morse.code(for: "E")?.elements == [.dot])
    #expect(Morse.code(for: "0")?.elements == [.dash, .dash, .dash, .dash, .dash])
    #expect(Morse.code(for: "5")?.elements == [.dot, .dot, .dot, .dot, .dot])
    #expect(Morse.code(for: "k") == nil)
    #expect(Morse.code(for: "?") == nil)
}

@Test func displayUsesDashDotAndSpaces() {
    #expect(Morse.code(for: "K")?.display == "— · —")
    #expect(Morse.code(for: "E")?.display == "·")
}

@Test func everyGridCharacterHasACode() {
    for c in Morse.gridOrder { #expect(Morse.code(for: c) != nil, "\(c)") }
}
