// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoicenoteAnki",
    platforms: [.iOS(.v17)],
    targets: [
        // Library target — excludes the app entry point, ContentView, and Views
        // (Views use iOS 26 .glassEffect() API and are not under test)
        .target(
            name: "VoicenoteAnki",
            path: "VoicenoteAnki",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
                "VoicenoteAnkiApp.swift",
                "ContentView.swift",
                "Views"
            ]
        ),
        .testTarget(
            name: "VoicenoteAnkiTests",
            dependencies: ["VoicenoteAnki"],
            path: "Tests/VoicenoteAnkiTests"
        )
    ]
)
