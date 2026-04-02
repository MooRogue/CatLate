import SwiftUI
import Translation

struct PendingTranslation: Identifiable, Equatable {
    let id = UUID()
    let sourceText: String
    let direction: ConversationDirection
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var direction: ConversationDirection = .default
    @Published var sourceTranscript = ""
    @Published var translatedText = ""
    @Published var statusMessage = "Tap Speak, say your phrase, then tap Hear."
    @Published var errorMessage: String?
    @Published var isListening = false
    @Published var isTranslating = false
    @Published var isSpeaking = false
    @Published var pendingTranslation: PendingTranslation?

    private let speechRecognizer = SpeechRecognizerService()
    private let playbackService = SpeechPlaybackService()

    init() {
        playbackService.onPlaybackStateChange = { [weak self] isSpeaking in
            self?.isSpeaking = isSpeaking
        }
    }

    var speakButtonTitle: String {
        isListening ? "Stop Listening" : "Speak \(direction.source.shortTitle)"
    }

    var speakButtonSubtitle: String {
        isListening ? "Tap when you finish talking." : "Use your voice. No typing."
    }

    var hearButtonTitle: String {
        "Hear \(direction.target.shortTitle)"
    }

    var hearButtonSubtitle: String {
        translatedText.isEmpty ? "Your translation will play here." : "Play the translated voice aloud."
    }

    var canHearTranslation: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isListening && !isTranslating
    }

    var canHearOriginal: Bool {
        !sourceTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isListening && !isTranslating
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            Task {
                await startListening()
            }
        }
    }

    func playTranslation() {
        guard canHearTranslation else {
            statusMessage = "Speak first. Then tap Hear."
            return
        }

        playbackService.speak(translatedText, language: direction.target)
        statusMessage = "Playing \(direction.target.title)."
    }

    func playOriginal() {
        guard canHearOriginal else { return }
        playbackService.speak(sourceTranscript, language: direction.source)
        statusMessage = "Playing your original words."
    }

    func stopPlayback() {
        playbackService.stop()
    }

    func reverseDirection() {
        speechRecognizer.cancelRecognition()
        playbackService.stop()
        isListening = false
        isTranslating = false
        pendingTranslation = nil
        direction.reverse()
        clearConversation(message: "Direction changed. Tap Speak in \(direction.source.title).")
    }

    func setLanguage(_ language: AppLanguage, for position: LanguagePosition) {
        speechRecognizer.cancelRecognition()
        playbackService.stop()
        isListening = false
        isTranslating = false
        pendingTranslation = nil

        switch position {
        case .source:
            if language == direction.target {
                direction.reverse()
            } else {
                direction.source = language
            }
        case .target:
            if language == direction.source {
                direction.reverse()
            } else {
                direction.target = language
            }
        }

        clearConversation(message: "Language updated. Tap Speak in \(direction.source.title).")
    }

    func completeTranslation(_ translatedText: String, for request: PendingTranslation) {
        guard pendingTranslation?.id == request.id else { return }

        self.translatedText = translatedText
        isTranslating = false
        pendingTranslation = nil
        errorMessage = nil
        statusMessage = "Ready. Tap Hear to play \(request.direction.target.title)."
    }

    func failTranslation(_ error: Error, for request: PendingTranslation) {
        guard pendingTranslation?.id == request.id else { return }

        isTranslating = false
        pendingTranslation = nil
        errorMessage = translationMessage(for: error)
        statusMessage = errorMessage ?? "Translation failed."
        translatedText = ""
    }

    private func startListening() async {
        playbackService.stop()
        clearConversation(message: "Listening in \(direction.source.title)…")
        errorMessage = nil
        translatedText = ""
        pendingTranslation = nil

        do {
            try await speechRecognizer.requestPermissions()
            try speechRecognizer.startRecognition(
                language: direction.source,
                onResult: { [weak self] text, isFinal in
                    guard let self else { return }
                    self.sourceTranscript = text
                    self.errorMessage = nil

                    if isFinal {
                        self.isListening = false
                        self.queueTranslation(for: text)
                    } else {
                        self.statusMessage = "Listening… Keep speaking."
                    }
                },
                onFailure: { [weak self] message in
                    guard let self else { return }
                    self.isListening = false
                    self.isTranslating = false
                    self.pendingTranslation = nil
                    self.errorMessage = message
                    self.statusMessage = message
                }
            )

            isListening = true
        } catch {
            isListening = false
            errorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    private func stopListening() {
        isListening = false
        speechRecognizer.stopAudioInput()

        if sourceTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statusMessage = "Listening stopped. Tap Speak and try again."
        } else {
            statusMessage = "Finishing your phrase…"
        }
    }

    private func queueTranslation(for text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            statusMessage = "I didn't hear words yet. Tap Speak and try again."
            return
        }

        isTranslating = true
        errorMessage = nil
        statusMessage = "Translating into \(direction.target.title)…"
        pendingTranslation = PendingTranslation(sourceText: trimmedText, direction: direction)
    }

    private func clearConversation(message: String) {
        sourceTranscript = ""
        translatedText = ""
        errorMessage = nil
        statusMessage = message
    }

    private func translationMessage(for error: Error) -> String {
        if TranslationError.unsupportedLanguagePairing ~= error {
            return "That language pair is not supported on this iPhone."
        }

        if TranslationError.unableToIdentifyLanguage ~= error {
            return "CatLate could not identify the spoken language. Try a shorter phrase."
        }

        if TranslationError.nothingToTranslate ~= error {
            return "There was nothing to translate yet."
        }

        return error.localizedDescription
    }
}
