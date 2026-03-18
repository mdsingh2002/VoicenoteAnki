import SwiftUI

/// Sheet that lets the user edit a single flashcard's front, back, difficulty and tags.
struct CardEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var card: Flashcard
    var onSave: (Flashcard) -> Void

    @State private var front: String
    @State private var back: String
    @State private var difficulty: Difficulty
    @State private var tagInput: String = ""
    @State private var tags: [String]

    init(card: Flashcard, onSave: @escaping (Flashcard) -> Void) {
        self.card = card
        self.onSave = onSave
        _front      = State(initialValue: card.front)
        _back       = State(initialValue: card.back)
        _difficulty = State(initialValue: card.difficulty)
        _tags       = State(initialValue: card.tags)
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("Edit Card")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Save", action: save)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .disabled(front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 18) {
                        // Front
                        editorField(label: "Front (Question / Term)", text: $front, minHeight: 90)

                        // Back
                        editorField(label: "Back (Answer / Definition)", text: $back, minHeight: 120)

                        // Difficulty picker
                        difficultyPicker

                        // Tags
                        tagsEditor
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    // MARK: - Components

    private func editorField(label: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.55))
            TextEditor(text: text)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 10) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    Button {
                        withAnimation(.spring(duration: 0.25)) { difficulty = level }
                    } label: {
                        Text(level.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if difficulty == level {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(difficultyGradient(level))
                                }
                            }
                            .glassEffect(difficulty == level ? .regular : .regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .opacity(difficulty == level ? 1.0 : 0.45)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.55))

            // Existing tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.8))
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular, in: Capsule())
                        }
                    }
                }
            }

            // Add tag input
            HStack(spacing: 8) {
                TextField("Add a tag…", text: $tagInput)
                    .font(.body)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { addTag() }

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func save() {
        var updated = card
        updated.front      = front.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.back       = back.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.difficulty = difficulty
        updated.tags       = tags
        onSave(updated)
        dismiss()
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func difficultyGradient(_ level: Difficulty) -> LinearGradient {
        switch level {
        case .easy:   return LinearGradient(colors: [.green.opacity(0.7), .mint.opacity(0.5)],   startPoint: .leading, endPoint: .trailing)
        case .medium: return LinearGradient(colors: [.orange.opacity(0.7), .yellow.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
        case .hard:   return LinearGradient(colors: [.red.opacity(0.7), .pink.opacity(0.5)],     startPoint: .leading, endPoint: .trailing)
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
