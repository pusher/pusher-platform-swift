// swift-tools-version:5.0

import PackageDescription

let package = Package(name: "PusherPlatform",
                      platforms: [.macOS(.v10_12),
                                  .iOS(.v10),
                                  .tvOS(.v10),
                                  .watchOS(.v3)],
                      products: [.library(name: "PusherPlatform",
                                          targets: ["PusherPlatform"])],
                      targets: [.target(name: "PusherPlatform",
                                        path: "Platform"),
                                .testTarget(name: "Unit Tests",
                                            path: "Unit Tests")],
                      swiftLanguageVersions: [.v4, .v4_2, .v5])
