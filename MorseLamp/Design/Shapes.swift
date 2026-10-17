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

/// 36 ticks, one per character in the Koch order: solid for unlocked, outlined for the next, dim for the rest.
struct TickRow: View {
    let unlocked: Int
    let hasNext: Bool
    /// The reveal: the tick that just turned solid is drawn in accent.
    var newestAccent = false

    @Environment(\.palette) private var palette

    init(unlocked: Int, hasNext: Bool, newestAccent: Bool = false) {
        self.unlocked = unlocked
        self.hasNext = hasNext
        self.newestAccent = newestAccent
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Morse.kochOrder.count, id: \.self) { index in
                tick(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(unlocked) of \(Morse.kochOrder.count) unlocked")
    }

    @ViewBuilder
    private func tick(at index: Int) -> some View {
        let shape = Capsule()
        if index < unlocked {
            shape.fill(newestAccent && index == unlocked - 1 ? palette.accent : palette.fg).frame(width: 2, height: 10)
        } else if index == unlocked && hasNext {
            shape.strokeBorder(palette.fgDim, lineWidth: 1).frame(width: 2, height: 10)
        } else {
            shape.fill(palette.muted2).frame(width: 2, height: 10)
        }
    }
}

extension Code {
    /// "dash dot dash", for VoiceOver.
    var spokenDescription: String {
        elements.map { $0 == .dot ? "dot" : "dash" }.joined(separator: " ")
    }
}
