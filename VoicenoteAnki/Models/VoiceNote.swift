import Foundation

struct VoiceNote: Identifiable {
    let id: UUID
    let date: Date
    let audioFileURL: URL
    var transcript: String
    var duration: TimeInterval

    init(id: UUID = UUID(), date: Date = .now, audioFileURL: URL, transcript: String = "", duration: TimeInterval = 0) {
        self.id = id
        self.date = date
        self.audioFileURL = audioFileURL
        self.transcript = transcript
        self.duration = duration
    }
}
