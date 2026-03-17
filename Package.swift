// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TabsAndChords",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TabsAndChords", targets: ["TabsAndChords"])
    ],
    targets: [
        .executableTarget(
            name: "TabsAndChords",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
