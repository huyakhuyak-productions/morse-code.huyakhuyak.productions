import SwiftUI

/// A segmented group with radio semantics: each segment is a button, the chosen one carries the selected trait.
struct LampSegmented<T: Hashable & CaseIterable>: View {
    let title: String
    @Binding var selection: T
    let label: (T) -> String

    @Namespace private var pill
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: String, selection: Binding<T>, label: @escaping (T) -> String) {
        self.title = title
        self._selection = selection
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(LampFont.body(14, relativeTo: .footnote))
                .foregroundStyle(palette.fgDim)
            HStack(spacing: 2) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    segment(option)
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.muted))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func segment(_ option: T) -> some View {
        let selected = option == selection
        return Button {
            withAnimation(reduceMotion ? nil : .lamp(0.2)) { selection = option }
        } label: {
            Text(label(option))
                .font(LampFont.title(15, relativeTo: .subheadline))
                .foregroundStyle(selected ? palette.bg : palette.fg)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.fg)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
