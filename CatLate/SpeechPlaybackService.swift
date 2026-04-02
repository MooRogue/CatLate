import AVFAudio
import Foundation

@MainActor
final class SpeechPlaybackService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    var onPlaybackStateChange: (@MainActor (Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: AppLanguage) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        try? configureAudioSession()

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice =
            AVSpeechSynthesisVoice(language: language.speechLocaleIdentifier) ??
            AVSpeechSynthesisVoice(language: language.translationIdentifier)
        utterance.rate = 0.49
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
        onPlaybackStateChange?(true)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        onPlaybackStateChange?(false)
        deactivateAudioSession()
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension SpeechPlaybackService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onPlaybackStateChange?(false)
            deactivateAudioSession()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onPlaybackStateChange?(false)
            deactivateAudioSession()
        }
    }
}
