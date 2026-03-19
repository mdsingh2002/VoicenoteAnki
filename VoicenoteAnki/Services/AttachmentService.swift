import Foundation
import UniformTypeIdentifiers

/// Manages file attachments for flashcards.
/// Copies files into a dedicated `attachments/` subdirectory in Documents.
final class AttachmentService {

    static let shared = AttachmentService()

    private let fm = FileManager.default
    private let documentsURL: URL
    private let attachmentsURL: URL

    init() {
        documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        attachmentsURL = documentsURL.appendingPathComponent("attachments", isDirectory: true)
        try? fm.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Copies a file at `sourceURL` into the attachments directory and returns a `CardAttachment`.
    /// The caller is responsible for stopping any security-scoped resource access.
    func saveAttachment(from sourceURL: URL) throws -> CardAttachment {
        let ext = sourceURL.pathExtension.lowercased()
        let type = attachmentType(for: ext)
        let fileName = "\(UUID().uuidString).\(ext)"
        let destinationURL = attachmentsURL.appendingPathComponent(fileName)
        try fm.copyItem(at: sourceURL, to: destinationURL)
        let relativePath = "attachments/\(fileName)"
        return CardAttachment(fileName: sourceURL.lastPathComponent, type: type, relativePath: relativePath)
    }

    /// Saves raw image data (e.g. from PhotosPicker) as a JPEG attachment.
    func saveImageData(_ data: Data, originalName: String = "photo") throws -> CardAttachment {
        let fileName = "\(UUID().uuidString).jpg"
        let destinationURL = attachmentsURL.appendingPathComponent(fileName)
        try data.write(to: destinationURL, options: .atomic)
        let relativePath = "attachments/\(fileName)"
        return CardAttachment(fileName: originalName, type: .image, relativePath: relativePath)
    }

    /// Deletes the file associated with an attachment.
    func deleteAttachment(_ attachment: CardAttachment) {
        let fileURL = documentsURL.appendingPathComponent(attachment.relativePath)
        try? fm.removeItem(at: fileURL)
    }

    /// Resolves a `CardAttachment` to its full `URL` on disk.
    func resolvedURL(for attachment: CardAttachment) -> URL {
        documentsURL.appendingPathComponent(attachment.relativePath)
    }

    // MARK: - Private

    private func attachmentType(for ext: String) -> AttachmentType {
        let imageExts = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        let audioExts = ["m4a", "mp3", "wav", "aac", "caf"]
        if imageExts.contains(ext) { return .image }
        if audioExts.contains(ext) { return .audio }
        if ext == "pdf"            { return .pdf }
        return .other
    }
}
