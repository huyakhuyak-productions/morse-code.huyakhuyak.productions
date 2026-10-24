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
        #expect(Palette.dark.badText == Color(hex: 0xFF4D3D))
        #expect(Palette.light.badText == Color(hex: 0xC9281A))
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

    /// Only the confirm sheet's button is solid red; a destructive action that still confirms
    /// wears the muted pill with red text so it does not read as the screen's main action.
    @Test func primaryButtonRoleColours() {
        let p = Palette.dark
        #expect(PrimaryButton.fill(for: .primary, in: p) == p.key)
        #expect(PrimaryButton.text(for: .primary, in: p) == p.keyText)
        #expect(PrimaryButton.fill(for: .muted, in: p) == p.muted)
        #expect(PrimaryButton.text(for: .muted, in: p) == p.fg)
        #expect(PrimaryButton.fill(for: .destructive, in: p) == p.bad)
        #expect(PrimaryButton.text(for: .destructive, in: p) == .white)
        #expect(PrimaryButton.fill(for: .mutedDestructive, in: p) == p.muted)
        #expect(PrimaryButton.text(for: .mutedDestructive, in: p) == p.badText)
    }

    /// 17 pt button text needs 4.5:1; `bad` itself falls short on the light muted fill.
    @Test func redTextReadsOnMutedFill() {
        for palette in [Palette.dark, Palette.light] {
            #expect(contrastRatio(palette.badText, on: palette.muted) >= 4.5)
        }
    }

    private func contrastRatio(_ text: Color, on fill: Color) -> Double {
        let (a, b) = (relativeLuminance(text), relativeLuminance(fill))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// WCAG 2 relative luminance of an sRGB colour.
    private func relativeLuminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &alpha)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
