import SwiftUI
import Combine

@MainActor
final class RecordingViewModel: ObservableObject {

    // MARK: - Published state
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var liveTranscript = ""
    @Published private(set) var finalTranscript = ""
    @Published private(set) var powerLevel: Float = 0
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var savedNotes: [VoiceNote] = []
    @Published var errorMessage: String?

    // MARK: - Services
    private let audioService = AudioRecordingService()
    private let transcriptionService = SpeechTranscriptionService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        audioService.$isRecording
            .assign(to: &$isRecording)
        audioService.$currentPowerLevel
            .assign(to: &$powerLevel)
        audioService.$recordingDuration
            .assign(to: &$recordingDuration)
        audioService.$error
            .compactMap { $0?.localizedDescription }
            .assign(to: &$errorMessage)

        transcriptionService.$liveTranscript
            .assign(to: &$liveTranscript)
        transcriptionService.$isTranscribing
            .assign(to: &$isTranscribing)
        transcriptionService.$error
            .compactMap { $0?.localizedDescription }
            .assign(to: &$errorMessage)
    }

    // MARK: - Actions

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task { await startRecording() }
        }
    }

    private func startRecording() async {
        finalTranscript = ""
        liveTranscript = ""
        errorMessage = nil

        do {
            try await audioService.startRecording()
            try await transcriptionService.startLiveTranscription()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() {
        guard let fileURL = audioService.stopRecording() else { return }
        transcriptionService.stopLiveTranscription()

        let duration = recordingDuration
        let captured = liveTranscript

        // If live transcript is good, use it; otherwise re-transcribe from file
        if !captured.isEmpty {
            finalTranscript = captured
            saveNote(fileURL: fileURL, transcript: captured, duration: duration)
        } else {
            Task {
                isTranscribing = true
                do {
                    let text = try await transcriptionService.transcribe(fileURL: fileURL)
                    finalTranscript = text
                    saveNote(fileURL: fileURL, transcript: text, duration: duration)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isTranscribing = false
            }
        }
    }

    private func saveNote(fileURL: URL, transcript: String, duration: TimeInterval) {
        let note = VoiceNote(audioFileURL: fileURL, transcript: transcript, duration: duration)
        savedNotes.insert(note, at: 0)
    }

    // MARK: - Helpers

    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
