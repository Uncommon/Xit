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
            exclude: ["libgit2"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "XitGit",
            dependencies: [
                "Clibgit2",
                .product(name: "FakedMacro", package: "FakedMacro")
            ],
            path: "Sources/XitGit"
        ),
        .testTarget(
            name: "XitGitTests",
            dependencies: ["XitGit"]
        )
    ]
)
