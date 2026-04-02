import AVFAudio
import Foundation
import Speech

enum SpeechRecognizerError: LocalizedError {
    case microphonePermissionDenied
    case speechAuthorizationDenied
    case recognizerUnavailable
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access is required so CatLate can hear you."
        case .speechAuthorizationDenied:
            "Speech recognition access is required so CatLate can understand your words."
        case .recognizerUnavailable:
            "Speech recognition is not available right now."
        case .unsupportedLanguage(let language):
            "Speech recognition is not ready for \(language) on this device."
        }
    }
}

@MainActor
final class SpeechRecognizerService {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var isCancelling = false

    func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw SpeechRecognizerError.speechAuthorizationDenied
        }

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard microphoneAllowed else {
            throw SpeechRecognizerError.microphonePermissionDenied
        }
    }

    func startRecognition(
        language: AppLanguage,
        onResult: @escaping @MainActor (String, Bool) -> Void,
        onFailure: @escaping @MainActor (String) -> Void
    ) throws {
        cancelRecognition()
        isCancelling = false

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.speechLocaleIdentifier)) else {
            throw SpeechRecognizerError.unsupportedLanguage(language.title)
        }

        guard recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        speechRecognizer = recognizer

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    onResult(result.bestTranscription.formattedString, result.isFinal)
                    if result.isFinal {
                        self.finishRecognition()
                    }
                }

                if let error {
                    if self.isCancelling {
                        self.isCancelling = false
                        self.finishRecognition()
                        return
                    }

                    self.finishRecognition()
                    onFailure(self.friendlyMessage(for: error))
                }
            }
        }
    }

    func stopAudioInput() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    func cancelRecognition() {
        isCancelling = true
        recognitionTask?.cancel()
        finishRecognition()
    }

    private func finishRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == "kAFAssistantErrorDomain" {
            return "CatLate stopped listening before it heard a full phrase. Tap Speak and try again."
        }

        if nsError.domain == "SFSpeechRecognitionErrorDomain" {
            return "Speech recognition had trouble finishing. Check your connection or try a shorter phrase."
        }

        return error.localizedDescription
    }
}
