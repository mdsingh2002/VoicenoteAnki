import SwiftUI
import AVFoundation

/// Compact inline player for a voice note (or any audio file).
struct VoiceNotePlayerView: View {
    let url: URL
    @StateObject private var player = AudioPlayerService()

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button {
                player.togglePlayPause(url: url)
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: player.isPlaying)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Seek bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = max(0, min(1, value.location.x / geo.size.width))
                                player.seek(to: ratio * player.duration)
                            }
                    )
                }
                .frame(height: 4)

                // Time labels
                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text(formatTime(player.duration))
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
