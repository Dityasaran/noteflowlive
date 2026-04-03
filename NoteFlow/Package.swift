// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoteFlow",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NoteFlow", targets: ["NoteFlow"])
    ],
    dependencies: [
        // Add any external dependencies here, e.g., for Keychain or SQLite if needed
    ],
    targets: [
        .executableTarget(
            name: "NoteFlow",
            dependencies: ["NoteFlowCore", "NoteFlowUI"]
        ),
        .executableTarget(
            name: "LoopbackTest",
            dependencies: ["NoteFlowCore"]
        ),
        .target(
            name: "NoteFlowCore",
            dependencies: []
        ),
        .target(
            name: "NoteFlowUI",
            dependencies: ["NoteFlowCore"]
        ),
        .testTarget(
            name: "NoteFlowTests",
            dependencies: ["NoteFlowCore"]
        )
    ]
)
