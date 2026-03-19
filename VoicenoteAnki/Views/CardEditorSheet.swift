import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Sheet that lets the user edit a single flashcard's front, back, difficulty, tags and attachments.
struct CardEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var card: Flashcard
    var onSave: (Flashcard) -> Void

    @State private var front: String
    @State private var back: String
    @State private var difficulty: Difficulty
    @State private var tagInput: String = ""
    @State private var tags: [String]
    @State private var attachments: [CardAttachment]

    // Attachment pickers
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFilePickerPresented = false
    @State private var attachmentError: String?

    init(card: Flashcard, onSave: @escaping (Flashcard) -> Void) {
        self.card = card
        self.onSave = onSave
        _front       = State(initialValue: card.front)
        _back        = State(initialValue: card.back)
        _difficulty  = State(initialValue: card.difficulty)
        _tags        = State(initialValue: card.tags)
        _attachments = State(initialValue: card.attachments)
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

                        // Attachments
                        attachmentsEditor
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPhoto(newItem) }
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.pdf, .audio, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
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

    // MARK: - Attachments Editor

    private var attachmentsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.55))

            // Error banner
            if let error = attachmentError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Existing attachments
            if !attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        attachmentRow(attachment)
                    }
                }
            }

            // Add attachment buttons
            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Photo", systemImage: "photo")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    isFilePickerPresented = true
                } label: {
                    Label("File", systemImage: "doc.badge.plus")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func attachmentRow(_ attachment: CardAttachment) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: attachment.type))
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 28)

            Text(attachment.fileName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                deleteAttachment(attachment)
            } label: {
                Image(systemName: "trash")
                    .font(.caption.bold())
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helpers

    private func save() {
        var updated = card
        updated.front       = front.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.back        = back.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.difficulty  = difficulty
        updated.tags        = tags
        updated.attachments = attachments
        onSave(updated)
        dismiss()
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func deleteAttachment(_ attachment: CardAttachment) {
        AttachmentService.shared.deleteAttachment(attachment)
        attachments.removeAll { $0.id == attachment.id }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        attachmentError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let name = item.itemIdentifier ?? "photo"
            let att = try AttachmentService.shared.saveImageData(data, originalName: name)
            attachments.append(att)
        } catch {
            attachmentError = "Could not load photo: \(error.localizedDescription)"
        }
        selectedPhotoItem = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        attachmentError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let att = try AttachmentService.shared.saveAttachment(from: url)
                attachments.append(att)
            } catch {
                attachmentError = "Could not import file: \(error.localizedDescription)"
            }
        case .failure(let error):
            attachmentError = "File import failed: \(error.localizedDescription)"
        }
    }

    private func iconName(for type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf:   return "doc.richtext"
        case .audio: return "waveform"
        case .other: return "paperclip"
        }
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
