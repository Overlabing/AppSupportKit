// swift-tools-version: 6.2
import PackageDescription

// Swift 6 language mode (strict concurrency) is the default with tools 6.2. No third-party dependency.
let package = Package(
    name: "AppSupportKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "Preferences", targets: ["Preferences"]),
        .library(name: "UserFacing", targets: ["UserFacing"]),
        .library(name: "DefaultApps", targets: ["DefaultApps"]),
        .library(name: "Spaces", targets: ["Spaces"]),
        .library(name: "SiteIcons", targets: ["SiteIcons"]),
    ],
    targets: [
        .target(name: "Localization"),
        .testTarget(name: "LocalizationTests", dependencies: ["Localization"], resources: [.process("Resources")]),
        .target(name: "Preferences", dependencies: ["Localization"], resources: [.process("Resources")]),
        .testTarget(name: "PreferencesTests", dependencies: ["Preferences"]),
        .target(name: "UserFacing", dependencies: ["Localization"], resources: [.process("Resources")]),
        .testTarget(name: "UserFacingTests", dependencies: ["UserFacing"]),
        .target(name: "DefaultApps"),
        .testTarget(name: "DefaultAppsTests", dependencies: ["DefaultApps"]),
        .target(name: "Spaces", dependencies: ["Localization", "Preferences"], resources: [.process("Resources")]),
        .testTarget(name: "SpacesTests", dependencies: ["Spaces", "Preferences"]),
        .target(name: "SiteIcons"),
        .testTarget(name: "SiteIconsTests", dependencies: ["SiteIcons"]),
    ]
)
