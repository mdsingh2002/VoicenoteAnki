import SwiftUI

/// Full-screen sheet showing generated cards before the user commits them to a deck.
struct GenerationPreviewView: View {
    @ObservedObject var vm: FlashcardsViewModel
    var deck: FlashcardDeck

    @State private var editingCard: Flashcard?
    @State private var expandedCardID: UUID?

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                // Summary strip
                summaryStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // Card list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(deck.cards) { card in
                            previewCardRow(card)
                        }
                        .onDelete { vm.deletePendingCard(at: $0) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }

                // Action bar
                actionBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .sheet(item: $editingCard) { card in
            CardEditorSheet(card: card) { updated in
                vm.updatePendingCard(updated)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Review Cards")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Edit or delete before saving")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button(action: vm.discardPendingDeck) {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        HStack(spacing: 14) {
            statPill(value: "\(deck.cards.count)", label: "Cards", icon: "rectangle.stack")
            Spacer()
            ForEach(Difficulty.allCases, id: \.self) { diff in
                let count = deck.cards.filter { $0.difficulty == diff }.count
                if count > 0 {
                    statPill(value: "\(count)", label: diff.label, icon: "circle.fill", tint: difficultyColor(diff))
                }
            }
        }
    }

    private func statPill(value: String, label: String, icon: String, tint: Color = .white) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint.opacity(0.75))
            Text("\(value) \(label)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: - Card rows

    private func previewCardRow(_ card: Flashcard) -> some View {
        let isExpanded = expandedCardID == card.id
        return VStack(alignment: .leading, spacing: 0) {
            // Collapsed / header
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    expandedCardID = isExpanded ? nil : card.id
                }
            } label: {
                HStack(spacing: 12) {
                    difficultyDot(card.difficulty)

                    Text(card.front)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(isExpanded ? nil : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expanded body
            if isExpanded {
                Divider().overlay(.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 10) {
                    Text(card.back)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))

                    if !card.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(card.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .glassEffect(.regular, in: Capsule())
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Spacer()
                        Button {
                            editingCard = card
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .glassEffect(.regular.interactive(), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 14) {
            Button(action: vm.discardPendingDeck) {
                Text("Discard")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                vm.confirmPendingDeck(deck)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.bold())
                    Text("Save Deck (\(deck.cards.count))")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [.blue.opacity(0.7), .purple.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                )
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(deck.cards.isEmpty)
        }
    }

    // MARK: - Helpers

    private func difficultyDot(_ difficulty: Difficulty) -> some View {
        Circle()
            .fill(difficultyColor(difficulty))
            .frame(width: 8, height: 8)
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

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
}
