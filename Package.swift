// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SymfonyCLIMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.6.4"),
    ],
    targets: [
        .executableTarget(
            name: "SymfonyCLIMenuBar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
            resources: [
                .process("SymfonyCLIMenuBar/Resources")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "SymfonyCLIMenuBarTests",
            dependencies: ["SymfonyCLIMenuBar"],
            path: "Tests/SymfonyCLIMenuBarTests"
        )
    ]
)
