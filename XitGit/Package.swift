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
            name: "Clibgit2",
            cSettings: [
                .unsafeFlags(["-I../libgit2/include"]) 
            ]
        ),
        .target(
            name: "XitGit",
            dependencies: ["Clibgit2"],
            swiftSettings: [
                 .unsafeFlags(["-Xcc", "-I../libgit2/include"])
            ]
        ),
        .testTarget(
            name: "XitGitTests",
            dependencies: ["XitGit"],
            swiftSettings: [
                 .unsafeFlags(["-Xcc", "-I../libgit2/include"])
            ]
        )
    ]
)
