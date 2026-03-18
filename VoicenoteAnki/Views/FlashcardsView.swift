import SwiftUI

struct FlashcardsView: View {
    @ObservedObject var vm: FlashcardsViewModel

    var body: some View {
        ZStack {
            backgroundGradient

            if let deck = vm.activeDeck {
                studySessionView(deck: deck)
            } else {
                deckListView
            }
        }
        .animation(.spring(duration: 0.4), value: vm.activeDeck?.id)
    }

    // MARK: - Deck list

    private var deckListView: some View {
        VStack(spacing: 0) {
            headerBar(title: "Flashcard Decks", subtitle: "\(vm.decks.count) deck\(vm.decks.count == 1 ? "" : "s")")
                .padding(.top, 8)
                .padding(.horizontal, 16)

            if vm.decks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.decks) { deck in
                            deckCard(deck)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.3))
            Text("No decks yet")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.5))
            Text("Record a voice note and flashcards\nwill be generated automatically.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func deckCard(_ deck: FlashcardDeck) -> some View {
        Button { vm.startStudySession(deck: deck) } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))

                    difficultyRow(deck.cards)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func difficultyRow(_ cards: [Flashcard]) -> some View {
        let counts: [(Difficulty, Int)] = Difficulty.allCases.compactMap { diff in
            let count = cards.filter { $0.difficulty == diff }.count
            return count > 0 ? (diff, count) : nil
        }
        return HStack(spacing: 6) {
            ForEach(counts, id: \.0) { diff, count in
                Text("\(count) \(diff.label)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: Capsule())
            }
        }
    }

    // MARK: - Study session

    private func studySessionView(deck: FlashcardDeck) -> some View {
        VStack(spacing: 0) {
            sessionHeader(deck: deck)
                .padding(.top, 8)
                .padding(.horizontal, 16)

            Spacer().frame(height: 24)

            if vm.sessionComplete {
                sessionCompleteView
            } else if let card = vm.currentCard {
                // Progress bar
                progressBar
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Card
                FlashcardView(
                    card: card,
                    isShowingBack: vm.isShowingBack,
                    onFlip: vm.flipCard,
                    onSwipeLeft: vm.nextCard,
                    onSwipeRight: vm.previousCard
                )
                .padding(.horizontal, 20)
                .id(card.id)           // forces full re-render on card change
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer().frame(height: 24)

                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func sessionHeader(deck: FlashcardDeck) -> some View {
        HStack {
            Button(action: vm.endStudySession) {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(deck.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(vm.currentCardIndex + 1) of \(deck.cards.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Placeholder to balance the back button
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.12))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * vm.progressFraction, height: 4)
                    .animation(.spring(duration: 0.3), value: vm.progressFraction)
            }
        }
        .frame(height: 4)
    }

    private var navigationButtons: some View {
        HStack(spacing: 20) {
            Button(action: vm.previousCard) {
                Label("Prev", systemImage: "chevron.left")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(vm.currentCardIndex == 0 ? 0.3 : 0.9))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.currentCardIndex == 0)

            Button(action: vm.flipCard) {
                Text(vm.isShowingBack ? "Hide" : "Reveal")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: vm.nextCard) {
                Label("Next", systemImage: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Session complete

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.bounce)

            Text("Deck Complete!")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("You reviewed all \(vm.activeDeck?.cards.count ?? 0) cards.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 16) {
                Button(action: vm.restartSession) {
                    Label("Again", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: vm.endStudySession) {
                    Label("Done", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Shared

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

    private func headerBar(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
