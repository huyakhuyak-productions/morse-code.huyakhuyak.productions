import SwiftUI

/// A stepped slider. The value label updates instantly; VoiceOver adjusts it by one step.
struct LampSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    let onDrag: ((Double) -> Void)?

    @State private var trackWidth: CGFloat = 0
    @Environment(\.palette) private var palette

    private let knob: CGFloat = 28

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String, onDrag: ((Double) -> Void)? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
        self.onDrag = onDrag
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(LampFont.body(17))
                    .foregroundStyle(palette.fg)
                Spacer()
                Text(format(value))
                    .font(LampFont.body(17))
                    .monospacedDigit()
                    .foregroundStyle(palette.fgDim)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(palette.muted).frame(height: 4)
                Capsule().fill(palette.accent).frame(width: knob / 2 + fraction * travel, height: 4)
                Circle()
                    .fill(palette.fg)
                    .frame(width: knob, height: knob)
                    .offset(x: fraction * travel)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
            // Only the track takes drags, so a scroll that starts on the title row still scrolls.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        set(fraction: (gesture.location.x - knob / 2) / max(travel, 1))
                        onDrag?(value)
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(value + step)
            case .decrement: set(value - step)
            @unknown default: break
            }
        }
    }

    private var travel: CGFloat { max(trackWidth - knob, 0) }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        return span > 0 ? CGFloat((value - range.lowerBound) / span) : 0
    }

    private func set(fraction: CGFloat) {
        let clamped = min(max(fraction, 0), 1)
        set(range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound))
    }

    private func set(_ raw: Double) {
        let stepped = range.lowerBound + ((raw - range.lowerBound) / step).rounded() * step
        let clamped = min(max(stepped, range.lowerBound), range.upperBound)
        if clamped != value { value = clamped }
    }
}
