import MorseCore
import SwiftUI

/// The spec's settings copy, in one place so tests can pin it.
nonisolated enum SettingsCopy {
    static func answerModeExplanation(_ mode: AnswerMode) -> String {
        switch mode {
        case .automatic: "Choices until 10 letters are unlocked, then the keyboard."
        case .choices: "A few candidates every time."
        case .keyboard: "The full grid every time."
        }
    }

    static func paceLabel(_ pace: UnlockPace) -> String {
        switch pace {
        case .relaxed: "Relaxed"
        case .standard: "Standard"
        case .strict: "Strict"
        }
    }

    static func paceExplanation(_ pace: UnlockPace) -> String {
        switch pace {
        case .relaxed: "New letters come quickly. Expect to revisit some."
        case .standard: "The Koch 90% rule, trimmed for one tap at a time."
        case .strict: "Each letter seasons for 20 rounds in both skills first."
        }
    }

    static let speedExplanation = "15 or above trains your ear best"
    static let codesOnLockedExplanation = "Off is how Morse is taught: hear a letter before you see it."
    static let relearnTitle = "Relearn my rhythm?"
    static let relearnMessage = "The key will measure your dot length again from your next matched characters."
    static let resetTitle = "Reset all progress?"
    static let resetMessage = "This locks everything except K and M."
}

/// Five groups of custom controls bound straight to the saved settings. Every change saves.
struct SettingsView: View {
    private enum Focus: Hashable { case relearn, reset }

    @State private var confirmingRelearn = false
    @State private var confirmingReset = false
    @State private var pitchSounding = false
    @AccessibilityFocusState private var focus: Focus?

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    group("Keying") {
                        LampSwitch("Strict timing", isOn: $app.state.settings.strictTiming)
                        PrimaryButton("Relearn my rhythm", role: .muted) { confirmingRelearn = true }
                            .accessibilityFocused($focus, equals: .relearn)
                    }
                    group("Listening") {
                        LampSegmented("Answer with", selection: $app.state.settings.answerMode) { mode in
                            switch mode {
                            case .automatic: "Automatic"
                            case .choices: "Choices"
                            case .keyboard: "Keyboard"
                            }
                        }
                        explanation(SettingsCopy.answerModeExplanation(app.state.settings.answerMode))
                        LampSlider("Character speed", value: wpm, in: 10...30, step: 1) { "\(Int($0)) wpm" }
                        explanation(SettingsCopy.speedExplanation)
                        PrimaryButton("Play sample", role: .muted) { playSample() }
                    }
                    group("Sound") {
                        LampSlider(
                            "Pitch",
                            value: $app.state.settings.pitchHz,
                            in: 400...900,
                            step: 10,
                            format: { "\(Int($0)) Hz" },
                            onDrag: { hz in
                                app.tone.setPitch(hz)
                                if !pitchSounding {
                                    pitchSounding = true
                                    app.tone.keyDown()
                                }
                            },
                            onRelease: {
                                pitchSounding = false
                                app.tone.keyUp()
                            }
                        )
                        LampSwitch("Haptics", isOn: $app.state.settings.haptics)
                    }
                    group("Appearance") {
                        LampSegmented("Theme", selection: $app.state.settings.theme) { theme in
                            switch theme {
                            case .system: "System"
                            case .dark: "Dark"
                            case .light: "Light"
                            }
                        }
                        LampSwitch("Codes on locked letters", explanation: SettingsCopy.codesOnLockedExplanation, isOn: $app.state.settings.codesOnLocked)
                    }
                    group("Progress") {
                        LampSegmented("Unlock pace", selection: $app.state.settings.pace, label: SettingsCopy.paceLabel)
                        explanation(SettingsCopy.paceExplanation(app.state.settings.pace))
                        PrimaryButton("Reset progress", role: .destructive) { confirmingReset = true }
                            .accessibilityFocused($focus, equals: .reset)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await app.tone.start()
            app.tone.setPitch(app.state.settings.pitchHz)
        }
        .onDisappear {
            app.tone.stop()
            app.save()
        }
        .onBackgroundReturn {
            // The app stops the engine on background; Play sample and the pitch preview need it back.
            await app.tone.start()
        }
        .onChange(of: app.state.settings) { _, settings in
            app.haptics.isEnabled = settings.haptics
            app.tone.setPitch(settings.pitchHz)
            app.save()
        }
        .onChange(of: app.state.settings.pace) { _, _ in
            app.refreshUnlock()
        }
        .confirmSheet(
            isPresented: $confirmingRelearn,
            title: SettingsCopy.relearnTitle,
            message: SettingsCopy.relearnMessage,
            destructiveTitle: "Relearn",
            onDismiss: { focus = .relearn }
        ) {
            app.relearnRhythm()
        }
        .confirmSheet(
            isPresented: $confirmingReset,
            title: SettingsCopy.resetTitle,
            message: SettingsCopy.resetMessage,
            destructiveTitle: "Reset",
            onDismiss: { focus = .reset }
        ) {
            app.resetProgress()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .accessibilityIdentifier("back")
            .accessibilityLabel("Back")
            Text("Settings")
                .font(LampFont.title(22))
                .foregroundStyle(palette.fg)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.horizontal, 8)
        // Its own container, like the drill top bar: otherwise the back button's accessibility node
        // swallows the scroll view after a reset and covers the whole screen.
        .accessibilityElement(children: .contain)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(LampFont.title(15, relativeTo: .subheadline))
                .foregroundStyle(palette.fgDim)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// The one explanatory line a group is allowed; it crossfades when its control changes.
    private func explanation(_ text: String) -> some View {
        CrossfadeText(text)
            .font(LampFont.body(14, relativeTo: .footnote))
            .foregroundStyle(palette.fgDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The slider works in Double; the setting is whole words per minute.
    private var wpm: Binding<Double> {
        Binding(
            get: { Double(app.state.settings.wpm) },
            set: { app.state.settings.wpm = Int($0.rounded()) }
        )
    }

    private func playSample() {
        guard let code = Morse.code(for: "K") else { return }
        let schedule = PlaybackSchedule(code: code, wpm: app.state.settings.wpm)
        Task { _ = await app.tone.play(schedule) }
    }
}
