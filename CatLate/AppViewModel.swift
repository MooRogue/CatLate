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
    private var translationTimeoutTask: Task<Void, Never>?

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

    func cancelTranslation() {
        guard isTranslating else { return }

        cancelTranslationTimeout()
        isTranslating = false
        pendingTranslation = nil
        errorMessage = nil
        statusMessage = "Translation stopped. Tap Speak and try again."
    }

    func reverseDirection() {
        speechRecognizer.cancelRecognition()
        playbackService.stop()
        cancelTranslationTimeout()
        isListening = false
        isTranslating = false
        pendingTranslation = nil
        direction.reverse()
        clearConversation(message: "Direction changed. Tap Speak in \(direction.source.title).")
    }

    func setLanguage(_ language: AppLanguage, for position: LanguagePosition) {
        speechRecognizer.cancelRecognition()
        playbackService.stop()
        cancelTranslationTimeout()
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

        cancelTranslationTimeout()
        self.translatedText = translatedText
        isTranslating = false
        pendingTranslation = nil
        errorMessage = nil
        statusMessage = "Ready. Tap Hear to play \(request.direction.target.title)."
    }

    func failTranslation(_ error: Error, for request: PendingTranslation) {
        guard pendingTranslation?.id == request.id else { return }

        cancelTranslationTimeout()
        isTranslating = false
        pendingTranslation = nil
        errorMessage = translationMessage(for: error)
        statusMessage = errorMessage ?? "Translation failed."
        translatedText = ""
    }

    private func startListening() async {
        playbackService.stop()
        clearConversation(message: "Listening in \(direction.source.title)…")
        cancelTranslationTimeout()
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
                    self.cancelTranslationTimeout()
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
        let request = PendingTranslation(sourceText: trimmedText, direction: direction)
        pendingTranslation = request
        scheduleTranslationTimeout(for: request)
    }

    private func clearConversation(message: String) {
        sourceTranscript = ""
        translatedText = ""
        errorMessage = nil
        statusMessage = message
    }

    private func scheduleTranslationTimeout(for request: PendingTranslation) {
        cancelTranslationTimeout()
        translationTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.expireTranslationIfNeeded(for: request)
        }
    }

    private func cancelTranslationTimeout() {
        translationTimeoutTask?.cancel()
        translationTimeoutTask = nil
    }

    private func expireTranslationIfNeeded(for request: PendingTranslation) {
        guard pendingTranslation?.id == request.id else { return }

        cancelTranslationTimeout()
        isTranslating = false
        pendingTranslation = nil
        translatedText = ""
        errorMessage = "Translation took too long. Tap Speak and try again."
        statusMessage = errorMessage ?? "Translation failed."
    }

    private func translationMessage(for error: Error) -> String {
        if error is CancellationError {
            return "Translation was interrupted. Tap Speak and try again."
        }

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
