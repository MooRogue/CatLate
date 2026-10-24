import SwiftUI
import Translation

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = AppViewModel()
    @State private var pickingLanguage: LanguagePosition?
    @State private var activeTranslationRequest: PendingTranslation?
    @State private var translationConfiguration: TranslationSession.Configuration?

    private let background = LinearGradient(
        colors: [
            Color("ThemeBackgroundTop"),
            Color("ThemeBackgroundBottom")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var prefersSingleColumnLayout: Bool {
        horizontalSizeClass != .regular
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        headerCard
                        languageCard
                        actionButtons
                        transcriptCard(
                            title: "What you said",
                            text: viewModel.sourceTranscript,
                            placeholder: "Your spoken words will appear here."
                        )
                        transcriptCard(
                            title: "\(viewModel.direction.target.title) translation",
                            text: viewModel.translatedText,
                            placeholder: "Your translation will appear here."
                        )
                        statusCard
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $pickingLanguage) { position in
                LanguagePickerView(
                    position: position,
                    selectedLanguage: position == .source ? viewModel.direction.source : viewModel.direction.target
                ) { language in
                    viewModel.setLanguage(language, for: position)
                    pickingLanguage = nil
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: viewModel.pendingTranslation) { _, newValue in
                activeTranslationRequest = newValue

                if let newValue {
                    translationConfiguration = TranslationSession.Configuration(
                        source: newValue.direction.source.localeLanguage,
                        target: newValue.direction.target.localeLanguage
                    )
                } else {
                    translationConfiguration = nil
                }
            }
            .translationTask(translationConfiguration) { session in
                guard let request = activeTranslationRequest else { return }

                do {
                    try await session.prepareTranslation()
                    let response = try await session.translate(request.sourceText)

                    await MainActor.run {
                        viewModel.completeTranslation(response.targetText, for: request)
                        activeTranslationRequest = nil
                        translationConfiguration = nil
                    }
                } catch {
                    await MainActor.run {
                        viewModel.failTranslation(error, for: request)
                        activeTranslationRequest = nil
                        translationConfiguration = nil
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tap. Talk. Hear.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Color("ThemePrimaryText"))

            Text("A simple translator built for people who want big buttons and clear steps instead of small menus.")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(Color("ThemeSecondaryText"))
                .fixedSize(horizontal: false, vertical: true)

            stepGuide
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color("ThemeSurface"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color("ThemeSurfaceBorder"), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 22, y: 10)
    }

    private var languageCard: some View {
        VStack(spacing: 16) {
            if prefersSingleColumnLayout {
                VStack(spacing: 14) {
                    languageButton(position: .source, language: viewModel.direction.source)
                    swapLanguagesButton
                    languageButton(position: .target, language: viewModel.direction.target)
                }
            } else {
                HStack(spacing: 14) {
                    languageButton(position: .source, language: viewModel.direction.source)
                    swapLanguagesButton
                    languageButton(position: .target, language: viewModel.direction.target)
                }
            }
        }
        .padding(20)
        .background(Color("ThemeLanguageSurface"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            actionButton(
                title: viewModel.speakButtonTitle,
                subtitle: viewModel.speakButtonSubtitle,
                symbol: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill",
                color: Color(red: 0.11, green: 0.36, blue: 0.82),
                isEnabled: !viewModel.isTranslating
            ) {
                viewModel.toggleListening()
            }

            actionButton(
                title: viewModel.hearButtonTitle,
                subtitle: viewModel.hearButtonSubtitle,
                symbol: "speaker.wave.3.fill",
                color: Color(red: 0.88, green: 0.40, blue: 0.20),
                isEnabled: viewModel.canHearTranslation
            ) {
                viewModel.playTranslation()
            }

            if viewModel.isTranslating {
                Button("Stop Translating") {
                    viewModel.cancelTranslation()
                }
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color("ThemePrimaryText"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("ThemeSurface"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color("ThemeSurfaceBorder"), lineWidth: 1)
                )
                .buttonStyle(.plain)
            }

            if viewModel.canHearOriginal {
                Button {
                    viewModel.playOriginal()
                } label: {
                    Text("Hear My Original Words")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color("ThemePrimaryText"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color("ThemeSurface"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if viewModel.isSpeaking {
                Button("Stop Audio") {
                    viewModel.stopPlayback()
                }
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .buttonStyle(.plain)
            }
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 38, weight: .bold))
                    .frame(width: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(.headline, design: .rounded, weight: .medium))
                        .opacity(0.88)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: color.opacity(0.28), radius: 16, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var stepGuide: some View {
        Group {
            if prefersSingleColumnLayout {
                VStack(spacing: 10) {
                    StepBadge(number: "1", text: "Tap Speak", style: .row)
                    StepBadge(number: "2", text: "Say your words", style: .row)
                    StepBadge(number: "3", text: "Tap Hear", style: .row)
                }
            } else {
                HStack(spacing: 12) {
                    StepBadge(number: "1", text: "Tap Speak", style: .card)
                    StepBadge(number: "2", text: "Say your words", style: .card)
                    StepBadge(number: "3", text: "Tap Hear", style: .card)
                }
            }
        }
    }

    private var swapLanguagesButton: some View {
        Button {
            viewModel.reverseDirection()
        } label: {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(red: 0.88, green: 0.40, blue: 0.20))
                .frame(width: 64, height: 64)
                .background(Color("ThemeSwapSurface"), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isListening || viewModel.isTranslating)
        .accessibilityLabel("Reverse languages")
    }

    private func languageButton(position: LanguagePosition, language: AppLanguage) -> some View {
        Button {
            pickingLanguage = position
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(position.title.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeTitle)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let englishSubtitle = language.englishSubtitle {
                        Text(englishSubtitle)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Text(position.subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(prefersSingleColumnLayout ? 1 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: prefersSingleColumnLayout ? 108 : 152,
                alignment: .leading
            )
            .padding(18)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isListening || viewModel.isTranslating)
        .opacity((viewModel.isListening || viewModel.isTranslating) ? 0.6 : 1)
    }

    private func transcriptCard(title: String, text: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Color("ThemePrimaryText"))

            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(text.isEmpty ? Color("ThemePlaceholderText") : Color("ThemeTranscriptText"))
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .multilineTextAlignment(.leading)
        }
        .padding(22)
        .background(Color("ThemeSurface"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color("ThemeSurfaceBorder"), lineWidth: 1)
        )
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.system(.headline, design: .rounded, weight: .heavy))

            Text(viewModel.statusMessage)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.95)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(statusBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 18, y: 10)
    }

    private var statusBackground: LinearGradient {
        if viewModel.errorMessage != nil {
            return LinearGradient(
                colors: [Color("ThemeErrorStart"), Color("ThemeErrorEnd")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if viewModel.isListening {
            return LinearGradient(
                colors: [Color("ThemeListeningStart"), Color("ThemeListeningEnd")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if viewModel.isTranslating {
            return LinearGradient(
                colors: [Color("ThemeWorkingStart"), Color("ThemeWorkingEnd")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color("ThemeReadyStart"), Color("ThemeReadyEnd")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct StepBadge: View {
    enum Style {
        case card
        case row
    }

    let number: String
    let text: String
    let style: Style

    var body: some View {
        Group {
            switch style {
            case .card:
                VStack(spacing: 10) {
                    numberBadge
                    Text(text)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color("ThemePrimaryText"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, minHeight: 92)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color("ThemeStepSurface"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            case .row:
                HStack(spacing: 12) {
                    numberBadge
                    Text(text)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color("ThemePrimaryText"))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color("ThemeStepSurface"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var numberBadge: some View {
        Text(number)
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color(red: 0.11, green: 0.36, blue: 0.82), in: Circle())
    }
}

private struct LanguagePickerView: View {
    let position: LanguagePosition
    let selectedLanguage: AppLanguage
    let onSelect: (AppLanguage) -> Void

    @Environment(\.dismiss) private var dismiss

    private let pickerBackground = Color("ThemePickerBackground")
    private let pickerCardBackground = Color("ThemePickerSurface")
    private let pickerCardBorder = Color("ThemePickerBorder")
    private let pickerPrimaryText = Color("ThemePickerPrimary")
    private let pickerSecondaryText = Color("ThemePickerSecondary")
    private let pickerSelectedBackground = Color("ThemePickerSelected")
    private let pickerSelectedSecondaryText = Color.white.opacity(0.82)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            onSelect(language)
                            dismiss()
                        } label: {
                            languageRow(for: language)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(pickerBackground)
            .navigationTitle(position.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func languageRow(for language: AppLanguage) -> some View {
        let isSelected = language == selectedLanguage
        let primaryTextColor = isSelected ? Color.white : pickerPrimaryText
        let secondaryTextColor = isSelected ? pickerSelectedSecondaryText : pickerSecondaryText

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(language.nativeTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let englishSubtitle = language.englishSubtitle {
                    Text(englishSubtitle)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(language.speechLocaleIdentifier)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelected ? Color.white.opacity(0.14) : Color("ThemeLocaleBackground"),
                        in: Capsule()
                    )
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? pickerSelectedBackground : pickerCardBackground,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.14) : pickerCardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.06), radius: isSelected ? 16 : 8, y: isSelected ? 10 : 4)
    }
}

#Preview {
    ContentView()
}
