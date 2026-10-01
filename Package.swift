// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StrasbourgMap",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .executable(name: "StrasbourgMap", targets: ["StrasbourgMap"]),
        .library(name: "WatchApp", targets: ["WatchApp"])
    ],
    targets: [
        .executableTarget(
            name: "StrasbourgMap",
            path: "StrasbourgMap"
        ),
        .target(
            name: "WatchApp",
            path: "WatchApp"
        )
    ]
)