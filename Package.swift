// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoicenoteAnki",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        // Library target — excludes the app entry point, ContentView, and Views
        // (Views use iOS 26 .glassEffect() API and are not under test).
        // AudioRecordingService and RecordingViewModel are also excluded because
        // they use AVAudioSession / AVAudioApplication.requestRecordPermission,
        // which are iOS/Mac-Catalyst-only APIs unavailable on native macOS.
        .target(
            name: "VoicenoteAnki",
            path: "VoicenoteAnki",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
                "VoicenoteAnkiApp.swift",
                "ContentView.swift",
                "Views",
                "Services/AudioRecordingService.swift",
                "ViewModels/RecordingViewModel.swift"
            ]
        ),
        .testTarget(
            name: "VoicenoteAnkiTests",
            dependencies: ["VoicenoteAnki"],
            path: "Tests/VoicenoteAnkiTests",
            // RecordingViewModelTests depends on RecordingViewModel which is
            // excluded from the macOS build above.
            exclude: ["ViewModels/RecordingViewModelTests.swift"]
        )
    ]
)
