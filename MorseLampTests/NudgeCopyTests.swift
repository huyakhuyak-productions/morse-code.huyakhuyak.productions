import Testing
import MorseCore
@testable import MorseLamp

struct NudgeCopyTests {
    @Test func keyingOffersListening() {
        #expect(NudgeCopy.title(from: .keying) == "Try listening?")
        #expect(NudgeCopy.message(from: .keying, next: "R", character: "M") == "You've keyed plenty. R is waiting on your ear: listen for M.")
        #expect(NudgeCopy.switchTitle(from: .keying) == "Listen now")
        #expect(NudgeCopy.stayTitle(from: .keying) == "Keep keying")
    }

    @Test func listeningOffersKeying() {
        #expect(NudgeCopy.title(from: .listening) == "Try keying?")
        #expect(NudgeCopy.message(from: .listening, next: "R", character: "M") == "You've listened plenty. R is waiting on your hand: key M.")
        #expect(NudgeCopy.switchTitle(from: .listening) == "Key now")
        #expect(NudgeCopy.stayTitle(from: .listening) == "Keep listening")
    }
}
