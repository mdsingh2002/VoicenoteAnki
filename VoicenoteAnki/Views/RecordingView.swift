import SwiftUI

struct RecordingView: View {

    @ObservedObject var vm: RecordingViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 8)

                Spacer()

                // Waveform
                WaveformView(powerLevel: vm.powerLevel, isActive: vm.isRecording)
                    .frame(height: 80)
                    .padding(.horizontal, 32)
                    .opacity(vm.isRecording || vm.isTranscribing ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.3), value: vm.isRecording)

                Spacer().frame(height: 40)

                recordButton

                Spacer().frame(height: 32)

                statusLabel

                // Flashcard generation status pill
                if vm.flashcardsVM.isGenerating {
                    generatingPill
                        .transition(.scale.combined(with: .opacity))
                        .padding(.top, 8)
                }

                Spacer()

                // Live / final transcript card
                if !vm.liveTranscript.isEmpty || !vm.finalTranscript.isEmpty {
                    transcriptCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .animation(.spring(duration: 0.4), value: vm.liveTranscript.isEmpty && vm.finalTranscript.isEmpty)
        .animation(.spring(duration: 0.35), value: vm.flashcardsVM.isGenerating)
    }

    // MARK: - Subviews

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.06, blue: 0.18),
                Color(red: 0.08, green: 0.04, blue: 0.22),
                Color(red: 0.02, green: 0.08, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VoiceNote")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Tap to record your thoughts")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if !vm.savedNotes.isEmpty {
                Text("\(vm.savedNotes.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var recordButton: some View {
        Button(action: vm.toggleRecording) {
            ZStack {
                if vm.isRecording {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.red.opacity(0.6), .pink.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                }

                Circle()
                    .frame(width: 90, height: 90)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .overlay {
                        Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(
                                vm.isRecording
                                ? LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .contentTransition(.symbolEffect(.replace))
                    }
            }
        }
        .buttonStyle(.plain)
        .onAppear { startPulseAnimation() }
        .onChange(of: vm.isRecording) { _, recording in
            if recording { startPulseAnimation() }
        }
    }

    private var statusLabel: some View {
        Group {
            if vm.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulseScale > 1.5 ? 0.4 : 1.0)
                    Text(vm.formattedDuration)
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(.white)
                }
            } else if vm.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("Transcribing…")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text(vm.savedNotes.isEmpty ? "Press the mic to start" : "\(vm.savedNotes.count) note\(vm.savedNotes.count == 1 ? "" : "s") saved")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.isRecording)
        .animation(.easeInOut(duration: 0.25), value: vm.isTranscribing)
    }

    private var generatingPill: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.white).scaleEffect(0.75)
            Text("Generating flashcards…")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    vm.isRecording ? "Live Transcript" : "Transcript",
                    systemImage: vm.isRecording ? "waveform" : "text.bubble"
                )
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))

                Spacer()

                // Manual generate / retry button (only when not recording and transcript exists)
                if !vm.isRecording, let note = vm.latestNote, !note.transcript.isEmpty {
                    if vm.flashcardsVM.isGenerating {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Button {
                            Task { await vm.flashcardsVM.generateDeck(for: note) }
                        } label: {
                            Label(
                                APIKeyService.shared.hasKey ? "Generate" : "Add Key",
                                systemImage: APIKeyService.shared.hasKey ? "rectangle.stack.badge.plus" : "key"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(APIKeyService.shared.hasKey ? .white : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular.interactive(), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView {
                Text(vm.isRecording ? vm.liveTranscript : vm.finalTranscript)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxHeight: 160)
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
            pulseScale = 2.0
        }
    }
}

#Preview {
    RecordingView(vm: RecordingViewModel())
}
