import SwiftUI

/// Single card with a 3-D flip animation and swipe-to-advance gesture.
struct FlashcardView: View {
    let card: Flashcard
    let isShowingBack: Bool
    let onFlip: () -> Void
    let onSwipeLeft: () -> Void    // next card
    let onSwipeRight: () -> Void   // previous card

    @State private var dragOffset: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
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
        .onChange(of: isShowingBack) { _, _ in
            // Reset drag when card changes
            dragOffset = 0
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
