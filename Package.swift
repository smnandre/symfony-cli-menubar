// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SymfonyCLIMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SymfonyCLIMenuBar",
            path: "Sources",
            resources: [
                .process("SymfonyCLIMenuBar/Resources")
            ]
        ),
        .testTarget(
            name: "SymfonyCLIMenuBarTests",
            dependencies: ["SymfonyCLIMenuBar"],
            path: "Tests/SymfonyCLIMenuBarTests"
        ),
    ]
)
