import Foundation
import Speech
import AVFoundation

final class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published var isRecording = false
    @Published var liveText = ""
    @Published var committedText = ""
    @Published var permissionStatus: SFSpeechRecognizerAuthorizationStatus
    @Published var errorMessage: String?

    var fullText: String {
        [committedText, liveText].filter { !$0.isEmpty }.joined(separator: " ")
    }

    @Published var locale: Locale = Locale(identifier: "de-DE")
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var restartTimer: Timer?
    private var tapInstalled = false
    // Incremented on endSession() so stale callbacks from cancelled tasks are ignored.
    private var sessionId = 0

    private init() {
        permissionStatus = SFSpeechRecognizer.authorizationStatus()
        let saved = SettingsService.shared.settings.transcriptionLocale
        locale = Locale(identifier: saved)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func setLocale(_ newLocale: Locale) {
        guard newLocale.identifier != locale.identifier else { return }
        locale = newLocale
        speechRecognizer = SFSpeechRecognizer(locale: newLocale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        persistLocale(newLocale.identifier)
        if isRecording {
            stopRecording()
        }
    }

    private func persistLocale(_ identifier: String) {
        var settings = SettingsService.shared.settings
        guard settings.transcriptionLocale != identifier else { return }
        settings.transcriptionLocale = identifier
        SettingsService.shared.updateSetting(settings)
    }

    func requestSpeechPermission(completion: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionStatus = status
                completion()
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil

        // Explicitly request microphone access — required on macOS even with the entitlement.
        // Without this the audio engine starts but silently produces no samples.
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.errorMessage = "Microphone access denied. Enable it in System Settings → Privacy & Security → Microphone."
                    return
                }
                self.isRecording = true
                self.beginSession()
                self.scheduleRestart()
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        restartTimer?.invalidate()
        restartTimer = nil
        // Set false BEFORE endSession so the cancelled-task callback sees isRecording=false
        // and doesn't trigger a restart.
        isRecording = false
        if !liveText.isEmpty {
            committedText = fullText
            liveText = ""
        }
        endSession()
    }

    func clearAll() {
        committedText = ""
        liveText = ""
        errorMessage = nil
    }

    // MARK: - Private

    private func beginSession() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition is not available on this device."
                self.isRecording = false
            }
            return
        }

        endSession()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request

        let capturedId = sessionId

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                // Discard callbacks from sessions that have been superseded.
                guard capturedId == self.sessionId else { return }

                if let result {
                    self.liveText = result.bestTranscription.formattedString
                }

                if let error, self.isRecording {
                    // Commit whatever we transcribed, then stop.
                    // The 50s proactive restart timer handles normal session limits,
                    // so errors here are genuine failures — don't auto-restart.
                    if !self.liveText.isEmpty {
                        self.committedText = self.fullText
                        self.liveText = ""
                    }
                    self.isRecording = false
                    self.endSession()
                    let code = (error as NSError).code
                    // 301 / 512 = user-cancelled (normal), 1107 = service ended normally
                    let silentCodes: Set<Int> = [301, 512, 1107]
                    if !silentCodes.contains(code) {
                        if code == 1101 {
                            self.errorMessage = "Internet connection required for speech recognition."
                        } else {
                            self.errorMessage = "Speech recognition stopped. Please try again."
                        }
                    }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Cannot start microphone: \(error.localizedDescription)"
                self.isRecording = false
            }
        }
    }

    private func endSession() {
        sessionId += 1
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        audioEngine.reset()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    // Proactively restart every 50s to stay under the ~60s SFSpeechRecognizer per-session limit.
    private func scheduleRestart() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: false) { [weak self] _ in
            guard let self, self.isRecording else { return }
            DispatchQueue.main.async {
                if !self.liveText.isEmpty {
                    self.committedText = self.fullText
                    self.liveText = ""
                }
                self.beginSession()
                self.scheduleRestart()
            }
        }
    }
}
