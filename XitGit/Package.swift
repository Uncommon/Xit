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
    dependencies: [
        .package(url: "https://github.com/Uncommon/FakedMacro", branch: "main")
    ],
    targets: [
        .target(
            name: "Clibgit2",
            cSettings: [
                .headerSearchPath("libgit2/include")
            ]
        ),
        .target(
            name: "XitGit",
            dependencies: ["Clibgit2", "FakedMacro"],
            swiftSettings: [
                 .unsafeFlags(["-Xcc", "-I", "../../libgit2/include"])
            ]
        ),
        .testTarget(
            name: "XitGitTests",
            dependencies: ["XitGit"],
            swiftSettings: [
                 .unsafeFlags(["-Xcc", "-I", "../../libgit2/include"])
            ]
        )
    ]
)
