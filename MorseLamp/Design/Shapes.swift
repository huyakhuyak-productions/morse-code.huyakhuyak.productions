import MorseCore
import SwiftUI

/// Dot and dash sizes: full in drills, hint under prompts, cell in the grid.
enum CodeScale {
    case full, hint, cell

    var dot: CGFloat {
        switch self {
        case .full: 16
        case .hint: 8
        case .cell: 4
        }
    }

    var dash: CGFloat {
        switch self {
        case .full: 48
        case .hint: 24
        case .cell: 10
        }
    }
}

struct Dot: View {
    var scale: CodeScale
    var color: Color

    var body: some View {
        Circle().fill(color).frame(width: scale.dot, height: scale.dot)
    }
}

struct Dash: View {
    var scale: CodeScale
    var color: Color

    var body: some View {
        Capsule().fill(color).frame(width: scale.dash, height: scale.dot)
    }
}

/// A character's code as dot and dash geometry, elements spaced one dot apart.
struct CodeView: View {
    let code: Code
    var scale: CodeScale
    var color: Color
    /// The element currently playing; the others drop to 40 % opacity.
    var highlighted: Int? = nil
    /// When set, the elements pop in one after another this many seconds apart (the reveal).
    var stagger: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    init(_ code: Code, scale: CodeScale, color: Color, highlighted: Int? = nil, stagger: Double? = nil) {
        self.code = code
        self.scale = scale
        self.color = color
        self.highlighted = highlighted
        self.stagger = stagger
    }

    var body: some View {
        HStack(spacing: scale.dot) {
            ForEach(Array(code.elements.enumerated()), id: \.offset) { index, element in
                Group {
                    switch element {
                    case .dot: Dot(scale: scale, color: color)
                    case .dash: Dash(scale: scale, color: color)
                    }
                }
                .opacity(entranceOpacity * (highlighted == nil || highlighted == index ? 1 : 0.4))
                .scaleEffect(entranceScale * (highlighted == index && !reduceMotion ? 1.15 : 1))
                .animation(.lamp(0.08), value: highlighted)
                .animation(.lamp(0.2).delay(reduceMotion ? 0 : Double(index) * (stagger ?? 0)), value: appeared)
            }
        }
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(code.spokenDescription)
    }

    private var entranceOpacity: Double {
        stagger == nil || appeared ? 1 : 0
    }

    private var entranceScale: CGFloat {
        stagger == nil || appeared || reduceMotion ? 1 : 0.6
    }
}

/// 36 ticks, one per character in the Koch order: solid for unlocked, outlined for the next
/// (filling from the bottom with the unlock distance), dim for the rest.
struct TickRow: View {
    let unlocked: Int
    let hasNext: Bool
    /// The unlock distance, 0...1, drawn inside the next tick.
    let nextFraction: Double
    /// The reveal: the tick that just turned solid is drawn in accent.
    var newestAccent = false

    @Environment(\.palette) private var palette

    init(unlocked: Int, hasNext: Bool, nextFraction: Double, newestAccent: Bool = false) {
        self.unlocked = unlocked
        self.hasNext = hasNext
        self.nextFraction = nextFraction
        self.newestAccent = newestAccent
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Morse.kochOrder.count, id: \.self) { index in
                tick(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder
    private func tick(at index: Int) -> some View {
        let shape = Capsule()
        if index < unlocked {
            shape.fill(newestAccent && index == unlocked - 1 ? palette.accent : palette.fg).frame(width: 2, height: 10)
        } else if index == unlocked && hasNext {
            shape.strokeBorder(palette.fgDim, lineWidth: 1)
                .overlay(alignment: .bottom) {
                    shape.fill(palette.fg).frame(height: 10 * nextFraction).distanceAnimation(nextFraction)
                }
                .frame(width: 2, height: 10)
        } else {
            shape.fill(palette.muted2).frame(width: 2, height: 10)
        }
    }

    /// "7 of 36 unlocked", then ", next 60% there" once the distance reads above 0 %.
    private var label: String {
        let count = "\(unlocked) of \(Morse.kochOrder.count) unlocked"
        guard hasNext, let distance = HomeCells.percentLabel(nextFraction) else { return count }
        return "\(count), next \(distance)"
    }
}

/// The grid cell's 14 pt rounded-rect ring from its top centre clockwise to `fraction`. SwiftUI's rounded-rect path
/// starts at the middle of the right edge and runs clockwise, so the top centre sits at 0.75 of it
/// for any size; the fill trims from there and wraps past the path's end.
struct RingFill: InsettableShape {
    var fraction: Double
    private var inset: CGFloat = 0

    init(fraction: Double) {
        self.fraction = fraction
    }

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let ring = RoundedRectangle(cornerRadius: 14 - inset, style: .continuous)
            .path(in: rect.insetBy(dx: inset, dy: inset))
        let start = 0.75
        let end = start + min(max(fraction, 0), 1)
        var path = ring.trimmedPath(from: start, to: min(end, 1))
        if end > 1 { path.addPath(ring.trimmedPath(from: 0, to: end - 1)) }
        return path
    }

    func inset(by amount: CGFloat) -> RingFill {
        var shape = self
        shape.inset += amount
        return shape
    }
}

extension View {
    /// Animates a change of the unlock distance with the standard motion; under Reduce Motion
    /// the old and new fills crossfade instead of the fill growing.
    func distanceAnimation(_ fraction: Double) -> some View {
        modifier(DistanceAnimation(fraction: fraction))
    }
}

private struct DistanceAnimation: ViewModifier {
    let fraction: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content.id(fraction).transition(.opacity)
            } else {
                content
            }
        }
        .animation(.lamp(0.32), value: fraction)
    }
}

extension Code {
    /// "dash dot dash", for VoiceOver.
    var spokenDescription: String {
        elements.map { $0 == .dot ? "dot" : "dash" }.joined(separator: " ")
    }
}
