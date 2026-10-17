import MorseCore
import SwiftUI

extension Animation {
    /// The spec's ease-out, `cubic-bezier(.2, 0, 0, 1)`.
    static func lamp(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0, 0, 1, duration: duration)
    }
}

/// Text that never cuts: each change crossfades with a 6 pt rise over 200 ms.
/// Under Reduce Motion the offset is dropped and only opacity animates.
struct CrossfadeText: View {
    let runs: [HomeSummary.Run]
    /// When set, normal runs use the Medium face and bold runs the SemiBold face at this size.
    let size: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ runs: [HomeSummary.Run], size: CGFloat) {
        self.runs = runs
        self.size = size
    }

    init(_ text: String) {
        self.runs = [HomeSummary.Run(text: text, isBold: false)]
        self.size = nil
    }

    private var key: String { runs.map(\.text).joined() }

    var body: some View {
        ZStack {
            styled
                .id(key)
                .transition(transition)
        }
        .animation(.lamp(0.2), value: key)
    }

    private var transition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 6)),
                removal: .opacity.combined(with: .offset(y: -6))
            )
        }
    }

    private var styled: Text {
        runs.reduce(Text(verbatim: "")) { partial, run in
            var next = Text(run.text)
            if let size {
                next = next.font(run.isBold ? LampFont.title(size) : LampFont.body(size))
            } else if run.isBold {
                next = next.fontWeight(.semibold)
            }
            return Text("\(partial)\(next)")
        }
    }
}

/// Press feedback: scale 0.96 over 80 ms. No scale under Reduce Motion.
struct PressScale: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.lamp(0.08), value: configuration.isPressed)
    }
}
