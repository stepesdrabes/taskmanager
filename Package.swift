// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaskManager",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "TaskManager",
            resources: [.copy("Localizations")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        )
    ]
)
