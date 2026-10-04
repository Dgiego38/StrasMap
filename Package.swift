// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StrasbourgMap",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "StrasbourgMap", targets: ["StrasbourgMap"])
    ],
    targets: [
        .executableTarget(
            name: "StrasbourgMap",
            path: "StrasbourgMap"
        )
    ]
)