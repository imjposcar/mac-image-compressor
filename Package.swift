// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mac-image-compressor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mac-image-compressor", targets: ["mac-image-compressor"])
    ],
    targets: [
        .executableTarget(
            name: "mac-image-compressor",
            path: ".",
            sources: ["main.swift"]
        )
    ]
)
