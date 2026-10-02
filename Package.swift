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
        .executable(name: "WatchApp", targets: ["WatchApp"])
    ],
    targets: [
        .executableTarget(
            name: "StrasbourgMap",
            path: "StrasbourgMap",
            exclude: ["WatchApp"],
            sources: ["Models", "Services", "Views", "StrasbourgMapApp.swift"]
        ),
        .executableTarget(
            name: "WatchApp",
            path: "WatchApp",
            exclude: []
        )
    ] 
)