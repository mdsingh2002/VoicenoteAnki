import SwiftUI

struct APIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var keyInput: String = ""
    @State private var isSecure: Bool = true
    @State private var showSavedConfirmation = false

    private let service = APIKeyService.shared

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("API Key")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Required to generate flashcards")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
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
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer().frame(height: 32)

                // Info card
                VStack(alignment: .leading, spacing: 10) {
                    Label("Get your key at console.anthropic.com", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Your key is stored securely in the iOS Keychain and never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                Spacer().frame(height: 24)

                // Input field
                VStack(alignment: .leading, spacing: 10) {
                    Text("Anthropic API Key")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.55))

                    HStack(spacing: 10) {
                        Group {
                            if isSecure {
                                SecureField("sk-ant-api03-...", text: $keyInput)
                            } else {
                                TextField("sk-ant-api03-...", text: $keyInput)
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            isSecure.toggle()
                        } label: {
                            Image(systemName: isSecure ? "eye" : "eye.slash")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Existing key indicator
                    if service.hasKey && keyInput.isEmpty {
                        Label("A key is already saved — enter a new one to replace it.", systemImage: "checkmark.shield")
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 28)

                // Save button
                Button(action: saveKey) {
                    HStack(spacing: 8) {
                        if showSavedConfirmation {
                            Image(systemName: "checkmark")
                                .symbolEffect(.bounce)
                        }
                        Text(showSavedConfirmation ? "Saved!" : "Save Key")
                            .font(.body.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.hasKey)
                .padding(.horizontal, 16)

                // Clear key
                if service.hasKey {
                    Button(role: .destructive) {
                        service.apiKey = nil
                        keyInput = ""
                    } label: {
                        Text("Remove saved key")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }

                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        service.apiKey = trimmed
        withAnimation(.spring(duration: 0.3)) { showSavedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
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

#Preview {
    APIKeySetupView()
}
