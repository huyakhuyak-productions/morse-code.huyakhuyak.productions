import CoreText
import os
import SwiftUI

/// Archivo, bundled: Black for glyphs and cells, SemiBold for buttons and titles, Medium for the rest.
enum LampFont {
    static let names = (black: "Archivo-Black", semiBold: "Archivo-SemiBold", medium: "Archivo-Medium")

    private static let logger = Logger(subsystem: "productions.huyakhuyak.morselamp", category: "fonts")

    /// Drill glyphs and letter cells. Callers apply tracking of −0.05 × size.
    static func glyph(_ size: CGFloat) -> Font {
        .custom(names.black, fixedSize: size)
    }

    static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom(names.semiBold, size: size, relativeTo: style)
    }

    static func body(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(names.medium, size: size, relativeTo: style)
    }

    /// Registers every bundled TTF with Core Text. Idempotent; failures are logged, never thrown.
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        if urls.isEmpty {
            logger.error("No bundled .ttf files found")
        }
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let cfError = error?.takeRetainedValue()
                // Re-registering an already registered font reports kCTFontManagerErrorAlreadyRegistered.
                if let cfError, CFErrorGetCode(cfError) != CTFontManagerError.alreadyRegistered.rawValue {
                    logger.error("Font registration failed for \(url.lastPathComponent, privacy: .public): \(String(describing: cfError), privacy: .public)")
                }
            }
        }
    }
}

extension View {
    /// The app's layouts are tuned up to xxLarge; larger sizes clamp rather than overflow.
    func lampDynamicTypeCap() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}
