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
    targets: [
        .target(
            name: "Clibgit2"
        ),
        .target(
            name: "XitGit",
            dependencies: ["Clibgit2"]
        ),
        .testTarget(
            name: "XitGitTests",
            dependencies: ["XitGit"]
        ),
    ]
)
