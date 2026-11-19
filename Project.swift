import ProjectDescription

// Generates POC-LiveActivity.xcodeproj with `tuist generate --no-open`.
// The generated project is shipped too, so Xcode alone is enough to build.

let sharedSettings: SettingsDictionary = [
    "SWIFT_VERSION": "5.0",
    "CODE_SIGN_STYLE": "Automatic",
    "TARGETED_DEVICE_FAMILY": "1",
]

/// Tuist sets an `AccentColor` the asset catalogs don't have, at target level.
let noAccentColor: SettingsDictionary = ["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": ""]

let project = Project(
    name: "POC-LiveActivity",
    options: .options(
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    settings: .settings(
        base: sharedSettings,
        configurations: [
            .debug(name: "Debug", xcconfig: "Config.xcconfig"),
            .release(name: "Release", xcconfig: "Config.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "POC-LiveActivity",
            destinations: .iOS,
            product: .app,
            productName: "POC-LiveActivity",
            bundleId: "$(BUNDLE_ID_PREFIX).POC-LiveActivity",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "App/Info.plist"),
            sources: ["App/**/*.swift", "Shared/**/*.swift"],
            resources: ["App/Assets.xcassets", "Shared/Shared.xcassets"],
            dependencies: [.target(name: "DownloadWidget")],
            settings: .settings(base: noAccentColor.merging([
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) MAIN_APP",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            ]) { $1 })
        ),
        .target(
            name: "DownloadWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "$(BUNDLE_ID_PREFIX).POC-LiveActivity.Widget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "Widget/Info.plist"),
            sources: ["Widget/**/*.swift", "Shared/**/*.swift"],
            resources: ["Shared/Shared.xcassets"],
            settings: .settings(base: noAccentColor)
        ),
    ]
)
