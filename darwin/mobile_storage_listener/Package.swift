// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "mobile_storage_listener",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "mobile-storage-listener", targets: ["mobile_storage_listener"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "mobile_storage_listener",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
