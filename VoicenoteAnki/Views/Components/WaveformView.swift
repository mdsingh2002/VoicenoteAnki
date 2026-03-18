import SwiftUI

/// Animated waveform that reacts to the current audio power level.
struct WaveformView: View {
    let powerLevel: Float          // 0–1
    let isActive: Bool

    private let barCount = 40
    @State private var idlePhase: Double = 0
    @State private var bars: [CGFloat] = Array(repeating: 0.08, count: 40)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !isActive)) { timeline in
            Canvas { context, size in
                let barWidth = size.width / CGFloat(barCount * 2 - 1)
                let midY = size.height / 2

                for i in 0..<barCount {
                    let x = CGFloat(i) * barWidth * 2
                    let height = bars[i] * size.height
                    let rect = CGRect(
                        x: x,
                        y: midY - height / 2,
                        width: barWidth,
                        height: height
                    )
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                    let progress = CGFloat(i) / CGFloat(barCount)
                    let color = Color(
                        hue: 0.56 + 0.1 * progress,
                        saturation: 0.7,
                        brightness: 0.95
                    )
                    context.fill(path, with: .color(color.opacity(isActive ? 0.9 : 0.35)))
                }
            }
            .onChange(of: timeline.date) { _, _ in
                updateBars()
            }
        }
        .onAppear {
            bars = randomIdleBars()
        }
    }

    // MARK: - Private

    private func updateBars() {
        if isActive {
            let base = CGFloat(powerLevel)
            bars = (0..<barCount).map { i in
                let wave = sin(Double(i) * 0.5 + idlePhase) * 0.15
                let noise = CGFloat.random(in: -0.05...0.05)
                return max(0.06, base * 0.8 + CGFloat(wave) + noise)
            }
            idlePhase += 0.25
        } else {
            // Gentle idle pulse
            idlePhase += 0.06
            bars = (0..<barCount).map { i in
                let wave = sin(Double(i) * 0.45 + idlePhase) * 0.06 + 0.1
                return CGFloat(wave)
            }
        }
    }

    private func randomIdleBars() -> [CGFloat] {
        (0..<barCount).map { _ in CGFloat.random(in: 0.06...0.14) }
    }
}

#Preview {
    WaveformView(powerLevel: 0.6, isActive: true)
        .frame(height: 80)
        .padding()
        .background(Color.black)
}
