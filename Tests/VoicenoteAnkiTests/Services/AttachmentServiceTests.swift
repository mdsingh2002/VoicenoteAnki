import XCTest
@testable import VoicenoteAnki

final class AttachmentServiceTests: XCTestCase {

    private var service: AttachmentService!
    /// Track attachments created during tests so we can clean them up.
    private var createdAttachments: [CardAttachment] = []

    override func setUp() {
        super.setUp()
        service = AttachmentService()
        createdAttachments = []
    }

    override func tearDown() {
        for attachment in createdAttachments {
            service.deleteAttachment(attachment)
        }
        createdAttachments = []
        service = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTempFile(named name: String, content: Data = Data("test".utf8)) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? content.write(to: url)
        return url
    }

    private func saveImage(_ data: Data = Data("fake-image".utf8), name: String = "photo") throws -> CardAttachment {
        let attachment = try service.saveImageData(data, originalName: name)
        createdAttachments.append(attachment)
        return attachment
    }

    private func saveFile(named name: String, content: Data = Data("data".utf8)) throws -> CardAttachment {
        let src = makeTempFile(named: name, content: content)
        let attachment = try service.saveAttachment(from: src)
        createdAttachments.append(attachment)
        try? FileManager.default.removeItem(at: src)
        return attachment
    }

    // MARK: - saveImageData

    func testSaveImageDataCreatesFile() throws {
        let attachment = try saveImage()
        let fileURL = service.resolvedURL(for: attachment)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSaveImageDataReturnsImageType() throws {
        let attachment = try saveImage()
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveImageDataUsesJPGExtension() throws {
        let attachment = try saveImage()
        XCTAssertTrue(attachment.relativePath.hasSuffix(".jpg"))
    }

    func testSaveImageDataUsesProvidedOriginalName() throws {
        let attachment = try saveImage(name: "my-photo")
        XCTAssertEqual(attachment.fileName, "my-photo")
    }

    func testSaveImageDataDefaultOriginalName() throws {
        let attachment = try saveImage()
        XCTAssertEqual(attachment.fileName, "photo")
    }

    func testSaveImageDataRelativePathStartsWithAttachments() throws {
        let attachment = try saveImage()
        XCTAssertTrue(attachment.relativePath.hasPrefix("attachments/"))
    }

    func testSaveImageDataWritesCorrectBytes() throws {
        let originalData = Data("hello-image".utf8)
        let attachment = try saveImage(originalData)
        let fileURL = service.resolvedURL(for: attachment)
        let readData = try Data(contentsOf: fileURL)
        XCTAssertEqual(readData, originalData)
    }

    func testSaveImageDataEachCallGeneratesUniqueFileName() throws {
        let att1 = try saveImage(name: "img1")
        let att2 = try saveImage(name: "img2")
        XCTAssertNotEqual(att1.relativePath, att2.relativePath)
    }

    // MARK: - saveAttachment: file type detection

    func testSaveAttachmentJPGReturnsImageType() throws {
        let attachment = try saveFile(named: "photo.jpg")
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveAttachmentJPEGReturnsImageType() throws {
        let attachment = try saveFile(named: "photo.jpeg")
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveAttachmentPNGReturnsImageType() throws {
        let attachment = try saveFile(named: "photo.png")
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveAttachmentGIFReturnsImageType() throws {
        let attachment = try saveFile(named: "anim.gif")
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveAttachmentHEICReturnsImageType() throws {
        let attachment = try saveFile(named: "photo.heic")
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveAttachmentWEBPReturnsImageType() throws {
        let attachment = try saveFile(named: "photo.webp")
        XCTAssertEqual(attachment.type, .image)
    }

    func testSaveAttachmentM4AReturnsAudioType() throws {
        let attachment = try saveFile(named: "recording.m4a")
        XCTAssertEqual(attachment.type, .audio)
    }

    func testSaveAttachmentMP3ReturnsAudioType() throws {
        let attachment = try saveFile(named: "song.mp3")
        XCTAssertEqual(attachment.type, .audio)
    }

    func testSaveAttachmentWAVReturnsAudioType() throws {
        let attachment = try saveFile(named: "sound.wav")
        XCTAssertEqual(attachment.type, .audio)
    }

    func testSaveAttachmentAACReturnsAudioType() throws {
        let attachment = try saveFile(named: "audio.aac")
        XCTAssertEqual(attachment.type, .audio)
    }

    func testSaveAttachmentCAFReturnsAudioType() throws {
        let attachment = try saveFile(named: "audio.caf")
        XCTAssertEqual(attachment.type, .audio)
    }

    func testSaveAttachmentPDFReturnsPDFType() throws {
        let attachment = try saveFile(named: "document.pdf")
        XCTAssertEqual(attachment.type, .pdf)
    }

    func testSaveAttachmentUnknownExtensionReturnsOtherType() throws {
        let attachment = try saveFile(named: "file.xyz")
        XCTAssertEqual(attachment.type, .other)
    }

    func testSaveAttachmentPreservesOriginalFileName() throws {
        let attachment = try saveFile(named: "my-recording.m4a")
        XCTAssertEqual(attachment.fileName, "my-recording.m4a")
    }

    func testSaveAttachmentRelativePathStartsWithAttachments() throws {
        let attachment = try saveFile(named: "note.mp3")
        XCTAssertTrue(attachment.relativePath.hasPrefix("attachments/"))
    }

    func testSaveAttachmentCopiesFileContent() throws {
        let content = Data("audio content bytes".utf8)
        let attachment = try saveFile(named: "test.mp3", content: content)
        let dest = service.resolvedURL(for: attachment)
        let readContent = try Data(contentsOf: dest)
        XCTAssertEqual(readContent, content)
    }

    func testSaveAttachmentEachCallGeneratesUniqueFileName() throws {
        let att1 = try saveFile(named: "a.mp3")
        let att2 = try saveFile(named: "b.mp3")
        XCTAssertNotEqual(att1.relativePath, att2.relativePath)
    }

    func testSaveAttachmentUppercaseExtensionIsTreatedAsLowercase() throws {
        // Extension is lowercased before comparison
        let attachment = try saveFile(named: "PHOTO.JPG")
        XCTAssertEqual(attachment.type, .image)
    }

    // MARK: - deleteAttachment

    func testDeleteAttachmentRemovesFile() throws {
        let attachment = try service.saveImageData(Data("x".utf8))
        let fileURL = service.resolvedURL(for: attachment)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        service.deleteAttachment(attachment)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        // Don't add to createdAttachments since already deleted
    }

    func testDeleteNonExistentAttachmentDoesNotCrash() {
        let attachment = CardAttachment(
            fileName: "ghost.jpg",
            type: .image,
            relativePath: "attachments/nonexistent-\(UUID().uuidString).jpg"
        )
        // Should not throw or crash
        service.deleteAttachment(attachment)
    }

    // MARK: - resolvedURL

    func testResolvedURLContainsAttachmentsComponent() throws {
        let attachment = try saveImage()
        let resolved = service.resolvedURL(for: attachment)
        XCTAssertTrue(resolved.path.contains("attachments"))
    }

    func testResolvedURLMatchesRelativePath() {
        let relativePath = "attachments/test-uuid.jpg"
        let attachment = CardAttachment(
            fileName: "test.jpg",
            type: .image,
            relativePath: relativePath
        )
        let resolved = service.resolvedURL(for: attachment)
        XCTAssertTrue(resolved.path.hasSuffix(relativePath))
    }
}
