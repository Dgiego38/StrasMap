// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StrasbourgMap",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "StrasbourgMap",
            targets: ["StrasbourgMap"]
        ),
    ],
    targets: [
        .target(
            name: "StrasbourgMap",
            path: "StrasbourgMap"
        )
    ]
)