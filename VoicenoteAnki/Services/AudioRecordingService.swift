import AVFoundation
import Combine

enum AudioRecordingError: LocalizedError {
    case permissionDenied
    case sessionSetupFailed(Error)
    case recordingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:       return "Microphone access was denied."
        case .sessionSetupFailed(let e): return "Audio session failed: \(e.localizedDescription)"
        case .recordingFailed(let e):    return "Recording failed: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {

    // MARK: - Published state
    @Published private(set) var isRecording = false
    @Published private(set) var currentPowerLevel: Float = 0   // normalised 0–1 for waveform
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var error: AudioRecordingError?

    // MARK: - Private
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var durationTimer: Timer?
    private var currentFileURL: URL?

    // MARK: - Public API

    /// Request microphone permission.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Start a new recording. Returns the file URL on success.
    @discardableResult
    func startRecording() async throws -> URL {
        guard await requestPermission() else {
            throw AudioRecordingError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            throw AudioRecordingError.sessionSetupFailed(error)
        }

        let url = makeFileURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            throw AudioRecordingError.recordingFailed(error)
        }

        currentFileURL = url
        isRecording = true
        recordingDuration = 0
        startTimers()
        return url
    }

    /// Stop the current recording. Returns the saved file URL.
    @discardableResult
    func stopRecording() -> URL? {
        recorder?.stop()
        stopTimers()
        isRecording = false
        currentPowerLevel = 0
        return currentFileURL
    }

    // MARK: - Private helpers

    private func makeFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("voicenote_\(Date().timeIntervalSince1970).m4a")
    }

    private func startTimers() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeter()
            }
        }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.recordingDuration += 0.1
            }
        }
    }

    private func stopTimers() {
        meterTimer?.invalidate(); meterTimer = nil
        durationTimer?.invalidate(); durationTimer = nil
    }

    private func updateMeter() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        // averagePower is in dBFS, roughly –60 to 0. Map to 0–1.
        let db = recorder.averagePower(forChannel: 0)
        let clamped = max(db, -60)
        currentPowerLevel = (clamped + 60) / 60
    }
}

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.error = .recordingFailed(NSError(domain: "AudioRecording", code: -1))
            }
        }
    }
}
