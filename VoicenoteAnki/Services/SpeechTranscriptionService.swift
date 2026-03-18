import Speech
import AVFoundation

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case unavailable
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:    return "Speech recognition permission was denied."
        case .unavailable:      return "Speech recognition is not available on this device."
        case .failed(let e):    return "Transcription failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class SpeechTranscriptionService: ObservableObject {

    @Published private(set) var liveTranscript = ""
    @Published private(set) var isTranscribing = false
    @Published var error: TranscriptionError?

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine: AVAudioEngine?
    private let recognizer = SFSpeechRecognizer(locale: .current)

    // MARK: - Live transcription (during recording)

    func startLiveTranscription() async throws {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else { throw TranscriptionError.notAuthorized }

        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do { try engine.start() } catch { throw TranscriptionError.failed(error) }

        isTranscribing = true
        liveTranscript = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if let error {
                    self.error = .failed(error)
                    self.stopLiveTranscription()
                }
            }
        }
    }

    func stopLiveTranscription() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isTranscribing = false
    }

    // MARK: - Post-recording transcription from file

    func transcribe(fileURL: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: TranscriptionError.failed(error))
                } else if let result, result.isFinal {
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
