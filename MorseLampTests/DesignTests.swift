import SwiftUI
import Testing
import MorseCore
import UIKit
@testable import MorseLamp

@MainActor
struct DesignTests {
    @Test func archivoFontsAreRegistered() {
        LampFont.registerBundledFonts()
        for name in [LampFont.names.black, LampFont.names.semiBold, LampFont.names.medium] {
            #expect(UIFont(name: name, size: 12) != nil, "\(name)")
        }
    }

    @Test func paletteTokensMatchSpec() {
        #expect(Palette.dark.accent == Color(hex: 0x3D5BFF))
        #expect(Palette.light.accent == Color(hex: 0x1F3BE6))
        #expect(Palette.dark.bg == Color(hex: 0x000000))
        #expect(Palette.light.fgDim == Color(hex: 0x6E6E6E))
        #expect(Palette.resolve(.dark) == .dark)
        #expect(Palette.resolve(.light) == .light)
    }

    @Test func cellFillByLevel() {
        let p = Palette.dark
        #expect(p.cellFill(level: .new) == p.muted)
        #expect(p.cellFill(level: .mastered) == p.accent)
    }

    @Test func lampEaseIsTheSpecCurve() {
        #expect(Animation.lamp(0.2) == .timingCurve(0.2, 0, 0, 1, duration: 0.2))
    }
}
