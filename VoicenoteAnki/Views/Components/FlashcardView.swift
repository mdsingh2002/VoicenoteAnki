import SwiftUI

/// Single card with a 3-D flip animation and swipe-to-advance gesture.
struct FlashcardView: View {
    let card: Flashcard
    let isShowingBack: Bool
    let onFlip: () -> Void
    let onSwipeLeft: () -> Void    // next card
    let onSwipeRight: () -> Void   // previous card
    /// Optional voice note URL from the source deck for playback.
    var voiceNoteURL: URL? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var showVoicePlayer = false
    @State private var showAttachments = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Back face
                cardFace(text: card.back, isFront: false)
                    .opacity(isShowingBack ? 1 : 0)
                    .rotation3DEffect(.degrees(isShowingBack ? 0 : -90), axis: (0, 1, 0))

                // Front face
                cardFace(text: card.front, isFront: true)
                    .opacity(isShowingBack ? 0 : 1)
                    .rotation3DEffect(.degrees(isShowingBack ? 90 : 0), axis: (0, 1, 0))
            }
            .offset(x: dragOffset)
            .rotationEffect(.degrees(dragOffset / 30))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.6
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 100
                        if value.translation.width < -threshold {
                            swipeOut(direction: -1, action: onSwipeLeft)
                        } else if value.translation.width > threshold {
                            swipeOut(direction: 1, action: onSwipeRight)
                        } else {
                            withAnimation(.spring(duration: 0.35)) { dragOffset = 0 }
                        }
                    }
            )
            .onTapGesture { onFlip() }
            .onChange(of: isShowingBack) { _, _ in dragOffset = 0 }

            // Action row: voice note + attachments
            if voiceNoteURL != nil || !card.attachments.isEmpty {
                actionRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Expanded voice player
            if showVoicePlayer, let url = voiceNoteURL {
                VoiceNotePlayerView(url: url)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Expanded attachments list
            if showAttachments && !card.attachments.isEmpty {
                attachmentsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Card face

    private func cardFace(text: String, isFront: Bool) -> some View {
        VStack(spacing: 16) {
            // Difficulty badge
            HStack {
                Spacer()
                difficultyBadge
            }

            Spacer()

            // Card text
            Text(text)
                .font(isFront ? .title3.bold() : .body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Spacer()

            // Hint
            Text(isFront ? "Tap to reveal answer" : "Swipe to continue")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))

            // Tags
            if !card.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(card.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .glassEffect(.regular, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            if voiceNoteURL != nil {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showVoicePlayer.toggle()
                        if showVoicePlayer { showAttachments = false }
                    }
                } label: {
                    Label("Voice Note", systemImage: showVoicePlayer ? "waveform.slash" : "waveform")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if !card.attachments.isEmpty {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showAttachments.toggle()
                        if showAttachments { showVoicePlayer = false }
                    }
                } label: {
                    Label("\(card.attachments.count)", systemImage: showAttachments ? "paperclip.slash" : "paperclip")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Attachments panel

    private var attachmentsPanel: some View {
        VStack(spacing: 8) {
            ForEach(card.attachments) { attachment in
                attachmentRow(attachment)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func attachmentRow(_ attachment: CardAttachment) -> some View {
        let url = AttachmentService.shared.resolvedURL(for: attachment)
        HStack(spacing: 10) {
            Image(systemName: iconName(for: attachment.type))
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24)

            if attachment.type == .image {
                attachmentImageRow(url: url, name: attachment.fileName)
            } else if attachment.type == .audio {
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.fileName)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                    VoiceNotePlayerView(url: url)
                }
            } else {
                Text(attachment.fileName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func attachmentImageRow(url: URL, name: String) -> some View {
        if let uiImage = loadImage(from: url) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity)
        } else {
            Text(name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func iconName(for type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf:   return "doc.richtext"
        case .audio: return "waveform"
        case .other: return "paperclip"
        }
    }

    private var difficultyBadge: some View {
        let colors: [Difficulty: [Color]] = [
            .easy:   [.green.opacity(0.8), .mint.opacity(0.6)],
            .medium: [.orange.opacity(0.8), .yellow.opacity(0.6)],
            .hard:   [.red.opacity(0.8), .pink.opacity(0.6)]
        ]

        return Text(card.difficulty.label)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: colors[card.difficulty] ?? [.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
    }

    // MARK: - Swipe helper

    private func swipeOut(direction: CGFloat, action: () -> Void) {
        withAnimation(.easeIn(duration: 0.2)) {
            dragOffset = direction * 500
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action()
            withAnimation(.none) { dragOffset = 0 }
        }
    }
}
