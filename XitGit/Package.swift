// swift-tools-version: 5.9
import PackageDescription
import Foundation

let fileManager = FileManager.default
let ssh2LinkerSettings: [LinkerSetting]

if fileManager.fileExists(atPath: "/opt/homebrew/lib/libssh2.dylib") {
    ssh2LinkerSettings = [.unsafeFlags(["/opt/homebrew/lib/libssh2.dylib"])]
} else if fileManager.fileExists(atPath: "/usr/local/lib/libssh2.dylib") {
    ssh2LinkerSettings = [.unsafeFlags(["/usr/local/lib/libssh2.dylib"])]
} else {
    ssh2LinkerSettings = [.linkedLibrary("ssh2")]
}

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
            path: "Sources/XitGit",
            linkerSettings: [
                .unsafeFlags(["-L", ".."]),
                .linkedLibrary("git2-mac"),
                .linkedLibrary("z"),
                .linkedLibrary("iconv"),
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation")
            ] + ssh2LinkerSettings
        ),
        .testTarget(
            name: "XitGitTests",
            dependencies: ["XitGit", "Clibgit2"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
