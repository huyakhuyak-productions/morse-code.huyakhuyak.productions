#!/usr/bin/env swift
// Composes the App Store screenshots: each raw simulator capture on a black 1320 x 2868
// canvas with its caption above it in Archivo SemiBold.
//
//   swift scripts/compose-screenshots.swift <raw-dir> <out-dir>
//
// Exit 2 if Archivo SemiBold cannot be loaded: the captions must never fall back to a
// system font.
import CoreGraphics
import CoreText
import Foundation
import ImageIO

let shots: [(file: String, slug: String, caption: String)] = [
    ("keying", "keying", "Key it."),
    ("listening", "listening", "Hear it."),
    ("home", "home", "Unlock the alphabet one letter at a time."),
    ("reveal", "reveal", "A new letter arrives as a sound first."),
    ("settings", "settings", "Strict timing, your pitch, your hand."),
]

let canvasWidth = 1320
let canvasHeight = 2868
let captureTop: CGFloat = 560        // points from the top of the canvas
let captureWidthFraction: CGFloat = 0.86
let cornerRadius: CGFloat = 110
let captionSize: CGFloat = 88
let captionMargin: CGFloat = 96
let fontPath = "MorseLamp/Resources/Fonts/Archivo-SemiBold.ttf"
let fontName = "Archivo-SemiBold"

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fail("usage: compose-screenshots.swift <raw-dir> <out-dir>", code: 64) }
let rawDir = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outDir = URL(fileURLWithPath: arguments[2], isDirectory: true)

// The script runs from the repo root (scripts/screenshots.sh does `cd` there).
let fontURL = URL(fileURLWithPath: fontPath)
var registrationError: Unmanaged<CFError>?
if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError) {
    let alreadyRegistered = (registrationError?.takeRetainedValue() as Error?).map {
        ($0 as NSError).code == CTFontManagerError.alreadyRegistered.rawValue
    } ?? false
    if !alreadyRegistered { fail("\(fontName) not available", code: 2) }
}
let font = CTFontCreateWithName(fontName as CFString, captionSize, nil)
guard CTFontCopyPostScriptName(font) as String == fontName else { fail("\(fontName) not available", code: 2) }

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func drawCaption(_ text: String, in context: CGContext, band: CGRect) {
    var alignment = CTTextAlignment.center
    let paragraph = withUnsafePointer(to: &alignment) { pointer in
        let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: pointer)]
        return CTParagraphStyleCreate(settings, settings.count)
    }
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!,
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
    ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let constraint = CGSize(width: band.width - 2 * captionMargin, height: band.height)
    let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, constraint, nil)
    let frameRect = CGRect(x: band.minX + captionMargin,
                           y: band.minY + (band.height - size.height) / 2,
                           width: constraint.width,
                           height: ceil(size.height) + 1)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: frameRect, transform: nil), nil)
    CTFrameDraw(frame, context)
}

for shot in shots.enumerated() {
    let input = rawDir.appendingPathComponent("\(shot.element.file).png")
    guard let capture = loadImage(input) else { fail("missing capture \(input.path)", code: 1) }
    guard let context = CGContext(data: nil, width: canvasWidth, height: canvasHeight, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("could not create canvas", code: 1)
    }
    let canvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0, 0, 1])!)
    context.fill(canvas)

    // Capture: 86 % of the width, centred, its top `captureTop` below the canvas top. CoreGraphics
    // measures from the bottom, so the rect may start below zero and bleed off the bottom edge.
    let width = (CGFloat(canvasWidth) * captureWidthFraction).rounded()
    let height = (width * CGFloat(capture.height) / CGFloat(capture.width)).rounded()
    let rect = CGRect(x: ((CGFloat(canvasWidth) - width) / 2).rounded(),
                      y: CGFloat(canvasHeight) - captureTop - height, width: width, height: height)
    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    context.clip()
    context.interpolationQuality = .high
    context.draw(capture, in: rect)
    context.restoreGState()

    drawCaption(shot.element.caption, in: context,
                band: CGRect(x: 0, y: CGFloat(canvasHeight) - captureTop, width: CGFloat(canvasWidth), height: captureTop))

    guard let image = context.makeImage() else { fail("could not render \(shot.element.slug)", code: 1) }
    let output = outDir.appendingPathComponent("\(shot.offset + 1)-\(shot.element.slug).png")
    guard let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil) else {
        fail("could not write \(output.path)", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("could not write \(output.path)", code: 1) }
    print("wrote \(output.path)")
}
