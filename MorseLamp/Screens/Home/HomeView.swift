import MorseCore
import SwiftUI

/// The grid is the dashboard and the reference sheet. One sentence above it, two doors below.
struct HomeView: View {
    @Binding var path: [Route]

    @State private var showingSheet = false
    @State private var sheetCharacter: Character = "K"
    @AccessibilityFocusState private var focusedCell: Character?

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        let progress = model.state.progress
        let summary = HomeSummary(progress: progress)
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 8) {
                    Dash(scale: .hint, color: palette.fg)
                    Dash(scale: .hint, color: palette.fg)
                }
                .accessibilityHidden(true)
                Spacer()
                Button { path.append(.settings) } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.fg)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityLabel("Settings")
            }
            CrossfadeText(summary.runs, size: 17)
                .foregroundStyle(palette.fg)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Morse.gridOrder, id: \.self) { character in
                    let state = HomeCells.state(of: character, in: progress)
                    CellView(
                        character: character,
                        state: state,
                        showsCode: HomeCells.showsCode(state, codesOnLocked: model.state.settings.codesOnLocked)
                    ) {
                        sheetCharacter = character
                        showingSheet = true
                    }
                    .accessibilityFocused($focusedCell, equals: character)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                PrimaryButton("Listen") { path.append(.listening) }
                PrimaryButton("Key") { path.append(.keying(practice: nil)) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(CharacterSheetPresenter(isPresented: $showingSheet, character: sheetCharacter, onDismiss: {
            focusedCell = sheetCharacter
        }) { character in
            path.append(.keying(practice: character))
        })
    }
}

/// Presents `CharacterSheet` with the shared scrim and slide.
private struct CharacterSheetPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let character: Character
    let onDismiss: () -> Void
    let onPractice: (Character) -> Void

    func body(content: Content) -> some View {
        content.lampPresentation(isPresented: $isPresented, onDismiss: onDismiss) {
            CharacterSheet(isPresented: $isPresented, character: character, onPractice: onPractice)
        }
    }
}
