import SwiftUI

// MARK: - Folder color palette

private let folderColors: [(hex: String, color: Color)] = [
    ("5E7CE2", Color(red: 0.37, green: 0.49, blue: 0.89)),
    ("4AC8A9", Color(red: 0.29, green: 0.78, blue: 0.66)),
    ("E2885E", Color(red: 0.89, green: 0.53, blue: 0.37)),
    ("D45EE2", Color(red: 0.83, green: 0.37, blue: 0.89)),
    ("E2C45E", Color(red: 0.89, green: 0.77, blue: 0.37)),
    ("5EAE5E", Color(red: 0.37, green: 0.68, blue: 0.37)),
]

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - FlashcardsView

struct FlashcardsView: View {
    @ObservedObject var vm: FlashcardsViewModel
    var onTapAPIKey: (() -> Void)? = nil

    // Navigation
    @State private var selectedFolderID: UUID? = nil
    @State private var isInFolder = false

    // Sheets & alerts
    @State private var editingCard: Flashcard?
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var newFolderColor = "5E7CE2"

    @State private var renamingFolder: Folder?
    @State private var renamingFolderName = ""

    @State private var deletingFolder: Folder?
    @State private var movingDeck: FlashcardDeck?

    var body: some View {
        ZStack {
            backgroundGradient

            if let deck = vm.activeDeck {
                studySessionView(deck: deck)
            } else if isInFolder, let folderID = selectedFolderID,
                      let folder = vm.folders.first(where: { $0.id == folderID }) {
                folderContentsView(folder: folder)
            } else {
                rootListView
            }
        }
        .animation(.spring(duration: 0.4), value: vm.activeDeck?.id)
        .animation(.spring(duration: 0.35), value: isInFolder)
        // Edit card sheet
        .sheet(item: $editingCard) { card in
            if let deck = vm.activeDeck {
                CardEditorSheet(card: card) { updated in
                    vm.updateCard(updated, in: deck)
                }
            }
        }
        // Create folder sheet
        .sheet(isPresented: $isCreatingFolder) {
            createFolderSheet
        }
        // Rename folder sheet
        .sheet(item: $renamingFolder) { folder in
            renameFolderSheet(folder: folder)
        }
        // Move deck sheet
        .sheet(item: $movingDeck) { deck in
            moveDeckSheet(deck: deck)
        }
        // Delete folder confirmation
        .alert("Delete Folder", isPresented: Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let f = deletingFolder { vm.deleteFolder(id: f.id) }
                deletingFolder = nil
            }
            Button("Cancel", role: .cancel) { deletingFolder = nil }
        } message: {
            Text("The folder will be removed. Decks inside will be moved to the root.")
        }
    }

    // MARK: - Root list (folders + unfiled decks)

    private var rootListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flashcard Decks")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("\(vm.decks.count) deck\(vm.decks.count == 1 ? "" : "s") · \(vm.folders.count) folder\(vm.folders.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                // New folder button
                Button {
                    newFolderName = ""
                    newFolderColor = "5E7CE2"
                    isCreatingFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(10)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)

                // API key indicator / button
                Button { onTapAPIKey?() } label: {
                    Image(systemName: APIKeyService.shared.hasKey ? "key.fill" : "key")
                        .font(.body)
                        .foregroundStyle(APIKeyService.shared.hasKey ? .white : .orange)
                        .padding(10)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 8)
            .padding(.horizontal, 16)

            statusBanners

            let rootDecks = vm.decks(in: nil)

            if vm.folders.isEmpty && rootDecks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        // Folders section
                        if !vm.folders.isEmpty {
                            ForEach(vm.folders) { folder in
                                folderRow(folder)
                            }
                        }

                        // Unfiled decks
                        if !rootDecks.isEmpty {
                            if !vm.folders.isEmpty {
                                HStack {
                                    Text("Unfiled")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.4))
                                        .textCase(.uppercase)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                            }

                            ForEach(rootDecks) { deck in
                                deckCard(deck, inFolder: false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    // MARK: - Folder row

    private func folderRow(_ folder: Folder) -> some View {
        Button {
            selectedFolderID = folder.id
            withAnimation { isInFolder = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: folder.colorHex))

                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    let count = vm.decks(in: folder.id).count
                    Text("\(count) deck\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
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
        .contextMenu {
            Button {
                renamingFolderName = folder.name
                renamingFolder = folder
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                deletingFolder = folder
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }

    // MARK: - Folder contents view

    private func folderContentsView(folder: Folder) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation { isInFolder = false }
                    selectedFolderID = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .padding(10)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color(hex: folder.colorHex))
                    Text(folder.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                // Folder actions menu
                Menu {
                    Button {
                        renamingFolderName = folder.name
                        renamingFolder = folder
                    } label: {
                        Label("Rename Folder", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingFolder = folder
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .padding(10)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 8)
            .padding(.horizontal, 16)

            let folderDecks = vm.decks(in: folder.id)

            if folderDecks.isEmpty {
                folderEmptyState(folder: folder)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(folderDecks) { deck in
                            deckCard(deck, inFolder: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private func folderEmptyState(folder: Folder) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 52))
                .foregroundStyle(Color(hex: folder.colorHex).opacity(0.5))
            Text("No decks in \"\(folder.name)\"")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.5))
            Text("Move a deck here using the\nmenu on any deck card.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Deck card

    private func deckCard(_ deck: FlashcardDeck, inFolder: Bool) -> some View {
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
        .contextMenu {
            // Move to folder options
            Menu {
                if deck.folderID != nil {
                    Button {
                        vm.moveDeck(id: deck.id, toFolder: nil)
                    } label: {
                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                    }
                    Divider()
                }
                ForEach(vm.folders.filter { $0.id != deck.folderID }) { folder in
                    Button {
                        vm.moveDeck(id: deck.id, toFolder: folder.id)
                        // If we moved a deck out of the current folder view, go back
                        if inFolder && deck.folderID != folder.id {
                            // stay in folder view — deck moved to a different folder
                        }
                    } label: {
                        Label(folder.name, systemImage: "folder")
                    }
                }
                if vm.folders.isEmpty {
                    Button {
                        newFolderName = ""
                        newFolderColor = "5E7CE2"
                        isCreatingFolder = true
                    } label: {
                        Label("New Folder…", systemImage: "folder.badge.plus")
                    }
                }
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                if let idx = vm.decks.firstIndex(where: { $0.id == deck.id }) {
                    vm.deleteDeck(at: IndexSet([idx]))
                }
            } label: {
                Label("Delete Deck", systemImage: "trash")
            }
        }
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

    // MARK: - Status banners

    @ViewBuilder
    private var statusBanners: some View {
        if vm.isGenerating {
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                if vm.queueDepth > 1 {
                    Text("\(vm.queueDepth) in queue…")
                } else {
                    Text("Generating flashcards…")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .padding(.top, 10)
            .transition(.scale.combined(with: .opacity))
        }

        if vm.deadLetterCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                Text("\(vm.deadLetterCount) generation\(vm.deadLetterCount == 1 ? "" : "s") failed")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Button {
                    Task { await vm.retryDeadLetters() }
                } label: {
                    Text("Retry")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .transition(.scale.combined(with: .opacity))
        }

        if let error = vm.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                Spacer()
                Button { vm.errorMessage = nil } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Create folder sheet

    private var createFolderSheet: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 24) {
                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.5))
                        HStack(spacing: 12) {
                            ForEach(folderColors, id: \.hex) { item in
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: newFolderColor == item.hex ? 3 : 0)
                                    )
                                    .onTapGesture { newFolderColor = item.hex }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isCreatingFolder = false }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            vm.createFolder(name: trimmed, colorHex: newFolderColor)
                        }
                        isCreatingFolder = false
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Rename folder sheet

    private func renameFolderSheet(folder: Folder) -> some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 24) {
                    TextField("Folder name", text: $renamingFolderName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.5))
                        HStack(spacing: 12) {
                            ForEach(folderColors, id: \.hex) { item in
                                let isCurrent = vm.folders.first(where: { $0.id == folder.id })?.colorHex == item.hex
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: isCurrent ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        vm.updateFolderColor(id: folder.id, colorHex: item.hex)
                                    }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Rename Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { renamingFolder = nil }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = renamingFolderName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            vm.renameFolder(id: folder.id, to: trimmed)
                        }
                        renamingFolder = nil
                    }
                    .disabled(renamingFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Move deck sheet

    private func moveDeckSheet(deck: FlashcardDeck) -> some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                List {
                    // Root option
                    Button {
                        vm.moveDeck(id: deck.id, toFolder: nil)
                        movingDeck = nil
                    } label: {
                        HStack {
                            Image(systemName: "tray")
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Unfiled (Root)")
                                .foregroundStyle(.white)
                            Spacer()
                            if deck.folderID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    ForEach(vm.folders) { folder in
                        Button {
                            vm.moveDeck(id: deck.id, toFolder: folder.id)
                            movingDeck = nil
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Color(hex: folder.colorHex))
                                Text(folder.name)
                                    .foregroundStyle(.white)
                                Spacer()
                                if deck.folderID == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { movingDeck = nil }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Empty state

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
                progressBar
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                FlashcardView(
                    card: card,
                    isShowingBack: vm.isShowingBack,
                    onFlip: vm.flipCard,
                    onSwipeLeft: vm.nextCard,
                    onSwipeRight: vm.previousCard,
                    voiceNoteURL: deck.sourceNote.audioFileURL
                )
                .padding(.horizontal, 20)
                .id(card.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer().frame(height: 24)

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

            Button {
                if let card = vm.currentCard {
                    editingCard = card
                }
            } label: {
                Image(systemName: "pencil")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(vm.currentCard != nil ? 1 : 0)
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
}
