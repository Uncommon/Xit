// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XitGit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "XitGit",
            targets: ["XitGit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Clibgit2",
            exclude: ["libgit2"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "XitGit",
            dependencies: ["Clibgit2"],
            path: "Sources/XitGitCore"
        ),
        .testTarget(
            name: "XitGitTests",
            dependencies: ["XitGit"]
        )
    ]
)
